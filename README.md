# Iron Gate

> *"Systems implicitly trust unverifiable inputs. This lab proves what happens when they shouldn't."*

Iron Gate is a detection engineering laboratory demonstrating how OWASP API Top 10 vulnerabilities create attack paths into adjacent OT/ICS networks. Built on Proxmox with four purpose-configured VMs, it generates, captures, and correlates adversarial telemetry across IT and OT layers — then tests whether purpose-built Loki alerting rules can actually catch it.

This lab is the technical foundation for [*Inputs Lie* Part 4: Detecting Lies at the Signal Layer](https://cornellsecurity.com/research/inputs-lie-part-4-detecting-lies-at-the-signal-layer/) — the culminating installment of a research series examining how critical infrastructure fails when systems trust what they shouldn't.

---

## Architecture

| VM | Role | IP | Key Services |
|----|------|----|--------------|
| `iron-gate-api` | Target — Vulnerable API | 10.0.0.100 | crAPI (8888), Mailhog (8025) |
| `iron-gate-attacker` | Adversary Platform | 10.0.0.101 | Kali Linux 2026.1, ffuf, sqlmap, Burp Suite, crapi-go |
| `iron-gate-ot` | ICS Honeypot | 10.0.0.103 | Conpot: Modbus (502), S7 (102), BACnet (47808) |
| `iron-gate-monitor` | Detection Stack | 10.0.0.102 | Grafana (3000), Loki (3100), Promtail |

All VMs operate on a flat, unsegmented 10.0.0.0/24 network — intentionally mirroring the IT/OT convergence architectures found in production critical infrastructure environments.

```
[Internet]
     |
[Home Router — 10.0.0.1]
     |
  [vmbr0 bridge — 10.0.0.0/24]
   +-----------+-----------+-----------+
   |           |           |           |
[API Target] [Attacker] [OT Honeypot] [Monitor]
 10.0.0.100  10.0.0.101  10.0.0.103  10.0.0.102
```

---

## What This Lab Demonstrates

- **BOLA attacks evade network-layer controls.** Broken Object Level Authorization via predictable IDs exploits application logic, not network permissions — firewall rules are irrelevant. Detection requires application log correlation.
- **A single API flaw crosses the IT/OT boundary.** An SSRF vulnerability in crAPI creates a direct attack path to the Conpot honeypot's Modbus interface, showing how web API compromise translates to OT network access.
- **Incomplete logging silently breaks detection rules.** Loki alerting rules for timing-based evasion and broken authentication fail without warning when upstream log sources are misconfigured — a direct implication for SOC detection coverage assurance.
- **Cross-layer correlation is the unsolved gap.** No tool in this stack natively correlates API security events with OT protocol anomalies. This lab quantifies that blind spot with reproducible scenarios.

---

## Detection Coverage

| Rule | Attack Pattern | OWASP API Mapping |
|------|---------------|-------------------|
| `bola-enumeration.yaml` | Sequential ID probing, horizontal privilege escalation | API1:2023 Broken Object Level Authorization |
| `broken-auth.yaml` | Credential stuffing, token reuse, session fixation | API2:2023 Broken Authentication |
| `data-exposure.yaml` | Excessive data in API responses, mass assignment | API3:2023 Broken Object Property Level Auth |
| `ot-probe.yaml` | Modbus/S7/BACnet protocol scanning from compromised host | OT lateral movement post-API pivot |

All rules are written in LogQL and deployed via Loki's ruler component. Alertmanager routes to Grafana for visualization.

---

## Repository Structure

```
iron-gate/
├── architecture/
│   ├── network-diagram.md     # VM topology and traffic flows
│   └── threat-model.md        # Attack scenarios and detection gaps
├── attacks/
│   ├── owasp-api-top10/       # Documented API attack scenarios
│   └── ot-targeting/          # ICS-specific attack chains
├── detection/
│   ├── grafana/               # Dashboards and Alertmanager config
│   └── loki/rules/            # LogQL detection rules (YAML)
├── lab-setup/
│   ├── ansible/               # Provisioning playbooks
│   └── proxmox/               # Hypervisor configuration
├── monitoring/promtail/       # Log shipping configuration
└── writeups/                  # Research drafts (Inputs Lie series)
```

---

## Skills & Technologies

| Domain | Technologies |
|--------|-------------|
| Virtualization | Proxmox VE, KVM, Ansible |
| API Security | crAPI, Burp Suite, ffuf, sqlmap, OWASP API Top 10 |
| ICS / OT | Conpot, Modbus, S7comm, BACnet |
| Observability | Grafana, Loki, Promtail, LogQL |
| Detection Engineering | LogQL alerting rules, Grafana Alertmanager |
| Operating Systems | Kali Linux 2026.1, Ubuntu |

---

## Research Context — *Inputs Lie* Series

This lab supports a four-part research series on how critical infrastructure fails when systems trust unverifiable inputs:

| Part | Title | Layer |
|------|-------|-------|
| [Part 1](https://cornellsecurity.com/research/inputs-lie-your-system-trusts-signals-it-shouldnt/) | Inputs Lie: Your System Trusts Signals It Shouldn't | Physical input manipulation — GPS, GNSS, NTP, RF |
| [Part 2](https://cornellsecurity.com/research/inputs-lie-part-2-kamacite-voltzite-and-the-signals-gap/) | KAMACITE, VOLTZITE, and the Signals Gap | Nation-state exploitation of signal-layer weaknesses |
| [Part 3](https://cornellsecurity.com/research/inputs-lie-part-3-logic-follows-lies/) | Logic Follows Lies: How PLCs and RTUs Execute Adversarial Intent | Control logic failures under adversarial inputs |
| [Part 4](https://cornellsecurity.com/research/inputs-lie-part-4-detecting-lies-at-the-signal-layer/) | Detecting Lies at the Signal Layer | Detection techniques + API-to-OT via Iron Gate lab |

**[cornellsecurity.com](https://cornellsecurity.com)** — Read the full series.
