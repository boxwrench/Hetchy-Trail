---
event_id: first_drop_at_pulgas
title: The First Drop at Pulgas
phase_id: phase_6
location_name: Pulgas, San Mateo County
mile_start: 165
mile_end: 167
historical_year_start: 1934
historical_year_end: 1934
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: dam_complete, mountain_tunnel_complete, foothill_tunnel_complete, san_joaquin_pipeline_complete, coast_range_tunnel_complete, alameda_siphon_complete, bay_crossing_complete
blocked_by_flags: 
---

## Description

Confirm that every upstream division is connected, open the system and convert accumulated Water Readiness into delivered water. Optionally hold a public ceremony recognizing the workforce and the completed gravity system.

## Historical fact

Pulgas Tunnel was begun in 1922 and carried Spring Valley water before the full Hetch Hetchy route was complete. The first Hetch Hetchy water reached Pulgas at 10:12 a.m. on October 24, 1934. A major public celebration followed on October 28.

## Source note

SFPUC 2005 history, "Hetch Hetchy Water Reaches San Francisco", p. 42 [SFPUC-2005]. Covers both October 1934 dates. One detail is not in the cited pages; see docs/SOURCES.md, open items. Design mapping: docs/Hetchy Trail Historical Game Mapping.pdf, sections 5-7.

## Assumption note

Visual note for the completion scene: depict the temporary ceremonial structure built for the 1934 first-water celebration, not the permanent Pulgas Water Temple, which was completed in 1938. The brief's 'Water Supply +5' is applied as readiness converted to delivered water via the hetch_hetchy_water_delivered flag, which is the win condition.

## Choice: Open the system with a public celebration

funds: -1
support: 3
readiness: 5
crew: 1
time: 0
grants: pulgas_connected, hetch_hetchy_water_delivered
repeat: false

At 10:12 a.m. on October 24, 1934, Sierra water arrives at Pulgas. Four days later the city celebrates beneath a temporary ceremonial structure, honoring twenty years of work and the people who did it.

## Choice: Open the valves quietly

funds: 0
support: 1
readiness: 5
crew: 1
time: 0
grants: pulgas_connected, hetch_hetchy_water_delivered
repeat: false

The water arrives with no speeches and no crowds - just engineers watching a gauge, and a city that will notice only that its taps never run dry.

