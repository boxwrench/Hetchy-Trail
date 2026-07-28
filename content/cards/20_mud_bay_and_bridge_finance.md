---
event_id: mud_bay_and_bridge_finance
title: Mud, Bay and Bridge Finance
phase_id: phase_6
location_name: Newark Slough and the Bay Crossing
mile_start: 140
mile_end: 167
historical_year_start: 1924
historical_year_end: 1925
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: 
blocked_by_flags: 
---

## Description

City funds are exhausted. Accept interim financing to retain hundreds of trained workers, then bury the large steel pipeline through the southern bay crossing.

## Historical fact

When city funds were exhausted, the Spring Valley Water Company advanced financing that helped prevent a prolonged shutdown and layoffs. Bay Crossing Pipeline No. 1 was placed in a trench through bay mud, reaching approximately 75 feet below the water surface in places. It was completed in 1925 and immediately used for local water transfers.

## Source note

SFPUC 2005 history, "Coast Range Tunnel", p. 40 [SFPUC-2005]. Also "Bay Crossing", p. 41. Design mapping: docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

Historically the Bay Crossing was finished in 1925, years before the Coast Range Tunnel - construction was simultaneous, not sequential. The game's mile-order compresses this; the card text and years preserve the real chronology. The brief's separate finance and construction effects are combined into the accept choice; refusing the advance is a gameplay counterfactual.

## Choice: Accept the interim financing

funds: 0
support: -1
readiness: 2
crew: 0
time: -2
grants: bay_crossing_complete
repeat: false

Spring Valley's advance keeps hundreds of trained workers on the payroll. The pipeline goes down through the bay mud, seventy-five feet below the water in places.

## Choice: Refuse private money and wait for city funds

funds: -2
support: 0
readiness: 2
crew: -2
time: 2
grants: bay_crossing_complete
repeat: false

The city keeps its independence and loses its momentum. Crews scatter during the shutdown, and reassembling them costs dearly.

