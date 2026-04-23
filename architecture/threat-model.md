# Threat Model

## System Under Analysis

An OT-adjacent environment where:
- An ICS honeypot (Conpot) represents the operational technology layer
- A web API application (crAPI) runs on a host with network adjacency to the OT layer
- Monitoring is present but not pre-tuned for API-layer OT threats

## Assets

| Asset | Value | Location |
|-------|-------|----------|
| OT process data | High — represents sensor/actuator state | iron-gate-ot |
| API authentication tokens | High — enables impersonation | iron-gate-api |
| API user data | Medium — PII, vehicle data in crAPI | iron-gate-api |
| Monitoring visibility | High — loss = blind defender | iron-gate-monitor |
| Network position (API host) | High — pivot point to OT | iron-gate-api |

## Threat Actors

### External Attacker (internet-facing API)
- Motivation: data exfiltration, disruption, ransomware pivot
- Access: HTTP/S to crAPI
- Capability: OWASP API Top 10 exploitation, credential stuffing, SSRF

### Insider / Compromised Credential
- Motivation: sabotage, espionage
- Access: valid API token + network access to OT segment
- Capability: authorized API calls for unauthorized purposes (BOLA), pivot to OT

### Nation-State / ICS-Targeting
- Motivation: ICS disruption
- Access: initially via API layer (lower-security entry point)
- Capability: API recon → pivot → OT protocol interaction

## Attack Surface

```
[External Attacker]
        │
        ▼ HTTP
┌──────────────┐
│   crAPI      │  ← OWASP API Top 10 surface
│  (iron-gate- │
│    api)      │
└──────┬───────┘
       │ Network adjacency (same /24)
       ▼
┌──────────────┐
│   Conpot     │  ← ICS protocol surface (Modbus, S7, BACnet)
│  (iron-gate- │
│    ot)       │
└──────────────┘
```

## STRIDE Analysis

### crAPI (iron-gate-api)

| Threat | Category | Attack | Mitigation |
|--------|----------|--------|------------|
| BOLA | Spoofing/Tampering | Access other users' vehicles via predictable IDs | Object-level auth checks |
| Broken Auth | Spoofing | Credential stuffing, token leakage | Rate limiting, token rotation |
| Excessive Data | Information Disclosure | Verbose API responses expose internal fields | Response filtering |
| SSRF | Elevation of Privilege | API endpoint proxies requests to internal hosts | SSRF controls, egress filtering |
| Resource Exhaustion | Denial of Service | Unbounded API calls | Rate limiting, quotas |

### Conpot / OT Layer (iron-gate-ot)

| Threat | Category | Attack | Mitigation |
|--------|----------|--------|------------|
| Unauthenticated Modbus | Spoofing | Write coils/registers without auth | Network segmentation (not present here) |
| S7 Stop CPU | Denial of Service | S7comm CPU stop command | Allowlisting by source IP |
| BACnet device scan | Information Disclosure | Enumerate devices, read properties | Protocol-aware firewall |
| API→OT pivot | Elevation of Privilege | Attacker on API host sends Modbus from localhost | East-west segmentation |

## Attack Chain: API-to-OT Pivot

This is the primary research scenario iron-gate is built to demonstrate.

```
Step 1: Recon
  Attacker discovers crAPI endpoint at 10.0.0.100:8888
  Enumerates users, vehicles, API structure

Step 2: Exploitation (BOLA)
  BOLA on /api/v2/vehicle/{id}/location returns all vehicle locations
  Attacker enumerates object IDs to harvest data

Step 3: SSRF / RCE
  SSRF via /api/v1/community/posts/new or similar endpoint
  Or: escalate to RCE via vulnerable component in crAPI stack

Step 4: Pivot
  Attacker now has code execution on 10.0.0.100
  Scans 10.0.0.0/24 → discovers 10.0.0.103 (iron-gate-ot)
  Directly sends Modbus requests: modbus_write_register(host=10.0.0.103, ...)

Step 5: OT Impact
  Modbus coils written → simulated actuator state changed
  No firewall between API host and OT segment
  Detection: Loki alerts on anomalous source IP for Modbus connections
```

## Detection Gaps Being Tested

1. **API-layer blind spots**: Most OT security tools don't ingest HTTP API logs
2. **Cross-layer correlation**: No native tooling correlates API events with OT events
3. **Object-level abuse**: BOLA is invisible to network-layer monitoring
4. **Pivot detection**: Lateral movement from IT→OT via same-subnet host is not alerted

## Defender Assumptions Being Violated

- "The OT network is isolated" — it isn't; it shares /24 with API host
- "We'd see network scanning" — pivot starts with a compromised host, not external scanning
- "Authentication covers it" — BOLA bypasses auth at the object level, not the session level
- "We have monitoring" — Grafana/Loki only fire if rules exist for these patterns

## Out of Scope

- Physical layer attacks (sensor tampering)
- Firmware-level ICS attacks
- Internet-exposed Proxmox (Proxmox is LAN-only)
- Windows-based attack paths
