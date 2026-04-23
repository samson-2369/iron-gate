---
title: "Inputs Lie Part 4: The API Layer"
series: "Inputs Lie"
part: 4
status: draft
lab: iron-gate
---

# Inputs Lie Part 4: The API Layer

*This is a working draft. The lab is being built alongside this writeup.*

---

## The Argument So Far

Parts 1–3 of this series built a case from the ground up:

**Part 1 (Physics)**: Sensors can be fed false inputs at the physical layer. GPS spoofing, sensor injection, environmental manipulation — the physics layer provides no authentication. Systems built on sensor data inherit that trust failure.

**Part 2 (Signals)**: Industrial protocols were designed for reliability, not security. Modbus, DNP3, and S7comm were built in environments where the attacker was assumed to be outside the wire. They aren't anymore.

**Part 3 (Logic Follows Lies)**: Once a false input enters a control system, logic faithfully processes it. The PLC doesn't know the sensor is lying. Safety systems built on bad data produce bad outputs. The lie propagates upward through every layer that trusted it.

The thesis through all three parts: **critical infrastructure fails not because attackers are sophisticated, but because defenders build systems that trust inputs they cannot verify.**

---

## Part 4: The API Layer

This part extends the argument upward — past the physics, past the protocols, into the application layer.

Modern operational technology doesn't exist in isolation. ICS systems are increasingly connected to:
- Enterprise IT networks (for remote monitoring and SCADA)
- Cloud platforms (for historian data, analytics)
- Web APIs (for maintenance portals, vendor integrations, mobile operator dashboards)

Each of these adjacencies creates an attack surface. And unlike the OT layer, which has at least two decades of security research pointing at it, the **API layer adjacent to OT is largely undefended**.

---

## The Novel Attack Surface

Here's the pattern I keep seeing in ICS environments:

```
[Internet or IT network]
         │
         ▼
[Web API / maintenance portal]
         │
    same /24 as
         │
         ▼
[OT network / field devices]
```

The API is the soft underbelly. It's built by software developers, not OT engineers. It inherits web application security debt — OWASP Top 10 vulnerabilities, weak authentication, excessive data exposure, SSRF. But it sits on a network that touches PLCs.

The OT security community defends the protocols. The web security community defends the APIs. Nobody's defending the junction.

---

## What iron-gate Proves

This lab is not a theoretical exercise. It's a working environment that demonstrates the attack chain end-to-end:

**Step 1: API exploitation (BOLA)**  
crAPI's vehicle endpoint returns data for any vehicle ID, not just the authenticated user's. An attacker enumerates IDs and maps all users and assets. Detection: near zero in most environments — this looks like normal API traffic at the network layer.

**Step 2: SSRF to internal network**  
crAPI's mechanic contact endpoint makes server-side HTTP requests. An attacker redirects these to internal hosts — including the OT host at 10.0.0.103. The API server becomes a proxy into the internal network.

**Step 3: Pivot to OT protocols**  
With code execution on the API host (or via SSRF), the attacker sends Modbus commands to Conpot on the same /24. The ICS honeypot responds — because Modbus has no authentication. The attacker reads register values, writes coils, simulates actuator manipulation.

**Step 4: Detection failure (without iron-gate rules)**  
Without the Loki rules in this lab, none of this is detected. API logs aren't correlated with Conpot logs. The pivot from 10.0.0.100 to 10.0.0.103 looks like legitimate internal traffic. The Modbus writes don't trigger anything because the OT monitoring stack isn't looking for source IPs.

---

## The Defender Gap

The core detection gap this lab exposes:

1. **Most OT monitoring tools don't ingest HTTP API logs.** They watch ICS protocols — Modbus, DNP3, S7comm. Not nginx access logs.

2. **Most web security tools don't know what Modbus is.** WAFs, SIEM correlation rules, and API gateways have no concept of "this API host just started talking to a PLC."

3. **Cross-layer correlation is essentially nonexistent.** The attacker moves from Layer 7 (HTTP API) to Layer 4 (TCP/Modbus) and the transition is invisible to both monitoring stacks.

The Loki rules in this lab are an attempt to close that gap — by shipping both API access logs and OT interaction logs to the same backend and writing rules that span both.

---

## What This Means for Defenders

If you run OT-adjacent systems with any API exposure:

1. **Map your adjacency.** Know which hosts can reach your OT network. Treat any host with both API exposure and OT network access as a high-value pivot target.

2. **Ship API logs to your OT monitoring stack.** Or ship OT logs to your SIEM. The correlation has to happen somewhere. Most organizations do neither.

3. **Write cross-layer detection rules.** The `APIHostConnectingToOT` Loki rule in this lab is trivial — it just watches for the API server's IP in Conpot logs. But without it, the pivot is invisible.

4. **Assume SSRF exists.** Any API that makes outbound HTTP requests is a potential SSRF vector. SSRF in an OT-adjacent API is categorically worse than SSRF in a normal web app — the internal network it can reach includes PLCs.

---

## Lab Setup

See [/lab-setup](/lab-setup) for full deployment instructions.

- `iron-gate-api` (10.0.0.100): crAPI + Docker
- `iron-gate-attacker` (10.0.0.101): Kali, attack tooling
- `iron-gate-monitor` (10.0.0.102): Grafana + Loki, detection stack
- `iron-gate-ot` (10.0.0.103): Conpot, ICS honeypot

---

## Status

- [x] Lab infrastructure deployed (Proxmox, 4 VMs)
- [ ] crAPI deployed and verified
- [ ] Conpot deployed and verified
- [ ] Monitoring stack deployed
- [ ] Promtail log shipping configured
- [ ] BOLA attack scenario documented with screenshots
- [ ] SSRF-to-OT pivot demonstrated
- [ ] Loki alerts firing on attack patterns
- [ ] Grafana dashboard screenshot for writeup
- [ ] Part 4 draft complete

---

*Part 5 (if this series continues): The Cloud Layer — when ICS historian data lands in S3 with a public ACL.*
