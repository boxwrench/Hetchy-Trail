---
event_id: six_camps_in_the_foothills
title: Six Camps in the Foothills
phase_id: phase_3
location_name: Foothill Tunnel camps
mile_start: 34
mile_end: 49
historical_year_start: 1925
historical_year_end: 1926
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: moccasin_power_available
blocked_by_flags: 
---

## Description

Decide how much infrastructure to provide before distributing the tunneling crews. Well-supplied camps retain workers and reduce future interruptions.

## Historical fact

Six construction camps supported Foothill Tunnel work. City crews installed camp water, electricity, telephones, roads and other support facilities before and during excavation.

## Source note

SFPUC historical materials, summarized in docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

Resource values are game-balancing numbers, not historical measurements.

## Choice: Fully service the camps

funds: -2
support: 0
readiness: 0
crew: 2
time: -1
grants: foothill_camps_established
repeat: false

Water, electricity, telephones and roads reach every camp before the crews spread out. Workers stay, and the tunnel work runs with fewer interruptions.

## Choice: Set up bare camps

funds: -1
support: 0
readiness: 0
crew: -2
time: 1
grants: foothill_camps_established
repeat: false

Tents and cookhouses go up fast and cheap. Workers drift away almost as fast, and every departure slows a heading.

