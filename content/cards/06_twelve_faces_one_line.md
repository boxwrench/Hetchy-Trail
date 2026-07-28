---
event_id: twelve_faces_one_line
title: Twelve Faces, One Line
phase_id: phase_2
location_name: Mountain Tunnel
mile_start: 30
mile_end: 49
historical_year_start: 1917
historical_year_end: 1925
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: construction_power_available
blocked_by_flags: 
---

## Description

Open additional shafts and headings to attack the tunnel simultaneously. More faces accelerate excavation but require more equipment, surveying and supervision.

## Historical fact

Mountain Tunnel was excavated from 12 faces. Access included the 786-foot Second Garrote shaft and 646-foot Big Creek shaft. The tunnel was completed in 1925.

## Source note

SFPUC 2005 history, "Mountain Tunnel", p. 35 [SFPUC-2005]. Design mapping: docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

The brief lists Water Readiness +2 only for the all-headings choice; both choices grant it here because the tunnel is completed either way, only slower.

## Choice: Open every heading

funds: -3
support: 0
readiness: 2
crew: -1
time: -2
grants: mountain_tunnel_complete
repeat: false

Portals, adits and deep shafts put twelve faces to work at once. The mountain gives way faster, at the cost of money, supervision, and tired crews.

## Choice: Work fewer headings

funds: -1
support: 0
readiness: 2
crew: 1
time: 2
grants: mountain_tunnel_complete
repeat: false

A smaller, steadier operation spends less and treats the crews better, but the tunnel takes longer to hole through.

