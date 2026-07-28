---
event_id: mitchell_shaft_memorial
title: Mitchell Shaft Memorial
phase_id: phase_5
location_name: Mitchell Shaft, Coast Range Tunnel
mile_start: 105
mile_end: 126
historical_year_start: 1931
historical_year_end: 1931
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: coast_range_committed
blocked_by_flags: 
---

## Description

An explosion at Mitchell Shaft has killed twelve workers. This is a fixed historical event, not a random or preventable player failure. Stop work, account for the dead, support the crews, and decide how thoroughly to review ventilation and gas monitoring before excavation resumes.

## Historical fact

Methane was encountered during Coast Range Tunnel construction. On July 17, 1931, an explosion at Mitchell Shaft killed 12 workers. Investigations documented existing safety precautions but did not establish one conclusive cause.

## Source note

SFPUC 2005 history, "Disastrous Explosion - 12 Lives Lost", p. 39 [SFPUC-2005]. Confirms twelve lives lost. One detail is not in the cited pages; see docs/SOURCES.md, open items. Design mapping: docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

Per the brief, this event always occurs and cannot be prevented by play. The immediate losses (Crew -3, Time +2, Support -1) are baked into both choices; the full stand-down partially offsets them (Funds -1, Crew +1, Support +1), matching the brief's structure.

## Choice: Order a full safety stand-down

funds: -1
support: 0
readiness: 0
crew: -2
time: 2
grants: mitchell_memorial_observed
repeat: false

Work stops. The dead are accounted for and their families supported. Ventilation is reviewed and gas monitoring reinforced at every heading before a single shift resumes.

## Choice: Hold a brief review and resume

funds: 0
support: -1
readiness: 0
crew: -3
time: 2
grants: mitchell_memorial_observed
repeat: false

The headings restart within weeks. The crews go back underground carrying the memory of Mitchell Shaft with them.

