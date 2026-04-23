# Network Diagram

## Physical Infrastructure

```
Internet
    │
    ▼
[Home Router / NAT]
    │ 10.0.0.1 (gateway)
    │
    ├── YOUR_PROXMOX_IP  Proxmox hypervisor (AMD A10-8700P, 11GB RAM, 4 vCPU)
    │
    └── 10.0.0.91   Kali workstation (external, pre-existing)
```

## Lab Network (vmbr0 bridge, 10.0.0.0/24)

```
                           vmbr0 (10.0.0.0/24)
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
          ▼                       ▼                       ▼
  ┌───────────────┐      ┌────────────────┐      ┌───────────────┐
  │ iron-gate-api │      │iron-gate-      │      │ iron-gate-ot  │
  │  10.0.0.100   │      │  attacker      │      │  10.0.0.103   │
  │               │      │  10.0.0.101    │      │               │
  │  Docker:      │      │               │      │  Conpot:      │
  │  :8888 crAPI  │      │  Kali 2026.1   │      │  :502  Modbus │
  │  :8025 mail   │◄─────│               │─────►│  :102  S7     │
  │               │      │  Tools:        │      │  :47808 BACnet│
  └───────┬───────┘      │  - ffuf        │      └───────┬───────┘
          │ Promtail     │  - sqlmap      │              │ Promtail
          │ :9080        │  - burpsuite   │              │ :9080
          ▼              │  - crapi-go    │              ▼
  ┌───────────────┐      └────────────────┘      ┌───────────────┐
  │iron-gate-     │                              │               │
  │  monitor      │◄─────────────────────────────┘               │
  │  10.0.0.102   │                                               │
  │               │                                               │
  │  Loki  :3100  │                                               │
  │  Grafana:3000 │                                               │
  └───────────────┘
```

## Port Reference

| Host | Port | Protocol | Service |
|------|------|----------|---------|
| iron-gate-api | 22 | TCP | SSH |
| iron-gate-api | 8888 | TCP | crAPI web |
| iron-gate-api | 8025 | TCP | crAPI mailhog |
| iron-gate-api | 8888 | TCP | crAPI API |
| iron-gate-attacker | 22 | TCP | SSH |
| iron-gate-monitor | 22 | TCP | SSH |
| iron-gate-monitor | 3000 | TCP | Grafana |
| iron-gate-monitor | 3100 | TCP | Loki (internal) |
| iron-gate-ot | 22 | TCP | SSH |
| iron-gate-ot | 102 | TCP | Conpot S7comm |
| iron-gate-ot | 502 | TCP | Conpot Modbus |
| iron-gate-ot | 47808 | UDP | Conpot BACnet |

## Traffic Flows

```
Attack traffic:   iron-gate-attacker → iron-gate-api (HTTP/HTTPS)
                  iron-gate-attacker → iron-gate-ot (Modbus/S7)
Log shipping:     iron-gate-api → iron-gate-monitor (Promtail → Loki)
                  iron-gate-ot → iron-gate-monitor (Promtail → Loki)
Visualization:    analyst browser → iron-gate-monitor:3000 (Grafana)
```

## Subnet Design Notes

All VMs are on the same flat /24 (10.0.0.0/24) bridged to the physical LAN.
No firewall segmentation between lab VMs — intentional for a research lab.
In a production OT environment, API and OT segments would be separated by a DMZ.
The lack of segmentation here is part of the threat model: it represents the common real-world
failure where IT/OT convergence happens without network redesign.
