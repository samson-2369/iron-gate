# iron-gate

**API Security Detection Lab in an ICS-Adjacent Proxmox Environment**

iron-gate is a hands-on security research lab demonstrating API attack surfaces in operational technology (OT)-adjacent environments. It is the practical foundation for [*Inputs Lie* Part 4](#writeups), extending the framework's thesis — that critical infrastructure systems implicitly trust unverifiable inputs — into the API layer.

---

## Research Context

The *Inputs Lie* framework argues that critical infrastructure fails not because attackers are sophisticated, but because defenders build systems that trust inputs they cannot verify — across physics, signals, and application layers.

This lab targets the application layer in OT-adjacent environments: **what happens when ICS-adjacent systems expose APIs, and no one is instrumented to detect abuse?**

Most OT security focuses on protocol-level threats (Modbus, DNP3, S7). iron-gate demonstrates that API exposure in adjacent systems creates a novel attack surface — one that inherits OT's weak detection posture while adding web application attack vectors.

**Core thesis being tested:**  
An attacker who compromises the API layer of an OT-adjacent system can pivot, manipulate process data, and move laterally — and most defenders will not see it.

---

## Architecture

```
10.0.0.0/24 (Proxmox host: YOUR_PROXMOX_IP)

┌─────────────────────────────────────────────────────┐
│                   iron-gate lab                      │
│                                                      │
│  ┌──────────────┐     ┌──────────────────────────┐  │
│  │iron-gate-api │     │   iron-gate-attacker     │  │
│  │ 10.0.0.100   │◄────│      10.0.0.101          │  │
│  │ crAPI+Docker │     │   Kali 2026.1            │  │
│  └──────┬───────┘     └──────────────────────────┘  │
│         │                          │                 │
│         │ logs                     │ attacks         │
│         ▼                          ▼                 │
│  ┌──────────────┐     ┌──────────────────────────┐  │
│  │iron-gate-    │     │    iron-gate-ot          │  │
│  │  monitor     │     │      10.0.0.103          │  │
│  │ 10.0.0.102   │◄────│   Conpot ICS honeypot    │  │
│  │Grafana+Loki  │     │  Modbus / S7 / BACnet    │  │
│  └──────────────┘     └──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

| VM | IP | OS | vCPU | RAM | Purpose |
|---|---|---|---|---|---|
| iron-gate-api | 10.0.0.100 | Ubuntu 22.04 | 1 | 2 GB | crAPI + Docker |
| iron-gate-attacker | 10.0.0.101 | Kali 2026.1 | 1 | 2 GB | Attack platform |
| iron-gate-monitor | 10.0.0.102 | Ubuntu 22.04 | 1 | 3 GB | Grafana + Loki |
| iron-gate-ot | 10.0.0.103 | Ubuntu 22.04 | 1 | 2 GB | Conpot ICS honeypot |

---

## Lab Components

### crAPI (Completely Ridiculous API)
OWASP's intentionally vulnerable API application. Deployed on `iron-gate-api` via Docker Compose. Used to demonstrate OWASP API Top 10 vulnerabilities in a controlled environment.

Target: `http://10.0.0.100:8888`

### Conpot ICS Honeypot
A low-interaction ICS honeypot simulating Modbus, Siemens S7, BACnet, and IPMI protocols. Deployed on `iron-gate-ot`. Represents the OT layer that API-adjacent systems interface with.

Modbus: `10.0.0.103:502`  
S7comm: `10.0.0.103:102`

### Grafana + Loki
Detection stack on `iron-gate-monitor`. Receives logs from `iron-gate-api` (API request logs) and `iron-gate-ot` (ICS protocol interactions). Dashboard tracks API activity patterns; Loki rules fire on OWASP API Top 10 signatures.

Grafana: `http://10.0.0.102:3000`

---

## Attack Scenarios

### OWASP API Top 10 ([/attacks/owasp-api-top10](/attacks/owasp-api-top10))
- API1: Broken Object Level Authorization (BOLA)
- API2: Broken Authentication
- API3: Broken Object Property Level Authorization
- API4: Unrestricted Resource Consumption
- API5: Broken Function Level Authorization
- API6: Unrestricted Access to Sensitive Business Flows
- API7: Server Side Request Forgery (SSRF)
- API8: Security Misconfiguration
- API9: Improper Inventory Management
- API10: Unsafe Consumption of APIs

### OT-Targeting via API Pivot ([/attacks/ot-targeting](/attacks/ot-targeting))
Scenarios where API compromise enables lateral movement to the OT layer — querying Conpot via pivot from crAPI server, demonstrating the API-to-OT attack chain.

---

## Detection Coverage

| Attack Pattern | Loki Rule | Grafana Panel |
|---|---|---|
| BOLA (object ID enumeration) | `bola-enumeration.yaml` | API Object ID Heatmap |
| Broken Auth (brute force) | `broken-auth.yaml` | Auth Failure Rate |
| Excessive Data Exposure | `data-exposure.yaml` | Response Size Anomalies |
| OT Protocol Probe | `ot-probe.yaml` | ICS Connection Map |

---

## Writeups

- [Inputs Lie Part 4: The API Layer](writeups/inputs-lie-part4.md) — *in progress*

### Inputs Lie Series
- Part 1: Physics Layer — sensor spoofing and signal manipulation
- Part 2: Signals Layer — protocol-level trust failures
- Part 3: Logic Follows Lies — how false inputs propagate through control logic
- Part 4: The API Layer ← *this lab*

---

## Setup

See [lab-setup/](lab-setup/) for Ansible playbooks and the Proxmox VM build script.

```bash
# From your workstation
cd lab-setup/ansible
ansible-playbook -i inventory.yml site.yml
```

SSH access uses key `~/.ssh/iron_gate` (ed25519).

---

## Proxmox Host

- IP: YOUR_PROXMOX_IP
- Node: pve
- Build script: [lab-setup/proxmox/vm-build.sh](lab-setup/proxmox/vm-build.sh)

> Set YOUR_PROXMOX_IP to your actual Proxmox host IP before running lab-setup scripts.
