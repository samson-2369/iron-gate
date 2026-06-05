---
title: "Detecting Lies at the Signal Layer"
series: "Inputs Lie"
part: 4
status: published
published_url: "https://cornellsecurity.com/research/inputs-lie-part-4-detecting-lies-at-the-signal-layer/"
published_date: "2026-05-05"
original_draft_title: "Inputs Lie Part 4: The API Layer"
---

# Detecting Lies at the Signal Layer

**Published on [cornellsecurity.com](https://cornellsecurity.com/research/inputs-lie-part-4-detecting-lies-at-the-signal-layer/).**

The full writeup lives at the link above. This file tracks lab build status and series context.

---

## Inputs Lie Series

- [Part 1 — Inputs Lie: Your System Trusts Signals It Shouldn't](https://cornellsecurity.com/research/inputs-lie-your-system-trusts-signals-it-shouldnt/)
- [Part 2 — KAMACITE, VOLTZITE, and the Signals Gap](https://cornellsecurity.com/research/inputs-lie-part-2-kamacite-voltzite-and-the-signals-gap/)
- [Part 3 — Logic Follows Lies: How PLCs and RTUs Execute Adversarial Intent](https://cornellsecurity.com/research/inputs-lie-part-3-logic-follows-lies/)
- [Part 4 — Detecting Lies at the Signal Layer](https://cornellsecurity.com/research/inputs-lie-part-4-detecting-lies-at-the-signal-layer/)

---

## Lab Build Status

- [x] Lab infrastructure deployed (Proxmox, 4 VMs)
- [x] crAPI deployed and verified
- [x] Conpot deployed and verified
- [x] Monitoring stack deployed (Grafana + Loki)
- [x] Promtail log shipping configured (conpot → Loki)
- [x] BOLA attack scenario documented with screenshots
- [x] SSRF-to-OT pivot demonstrated
- [x] Loki alerts firing on attack patterns
- [x] Grafana dashboard screenshot for writeup
- [x] Part 4 draft complete
