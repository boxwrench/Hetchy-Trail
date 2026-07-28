---
event_id: cut_the_first_road
title: Cut the First Road
phase_id: phase_1
location_name: Hog Ranch and Canyon Ranch
mile_start: 0
mile_end: 12
historical_year_start: 1914
historical_year_end: 1915
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: 
blocked_by_flags: 
---

## Description

Heavy work cannot begin until the city builds mountain access and establishes a local timber supply. Investing fully makes later dam and railroad work faster and improves camp conditions.

## Historical fact

Road work began around Hog Ranch in 1914. A sawmill at Canyon Ranch began operating in July 1915, approximately 4.5 miles from the dam site. The sawmill and its later replacement at Hog Ranch produced millions of board feet of construction lumber.

## Source note

SFPUC 2005 history, "Early Intake Powerhouse and Lake Eleanor", p. 32 [SFPUC-2005]. Confirms the sawmill and its move to Hog Ranch. One detail is not in the cited pages; see docs/SOURCES.md, open items. Design mapping: docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

Resource values are game-balancing numbers, not historical measurements. The brief's 'Time -1 on two later High Sierra cards' is consolidated into a single immediate time gain.

## Choice: Build the full road and sawmill

funds: -2
support: 0
readiness: 0
crew: 1
time: -1
grants: high_sierra_access_complete
repeat: false

Crews cut a real supply corridor into the mountains. Later dam and railroad work will move faster, and the camps are better for it.

## Choice: Cut only minimal access

funds: -1
support: 0
readiness: 0
crew: -1
time: 1
grants: high_sierra_access_complete
repeat: false

A rough track opens the valley for less money now, but every load of cement and timber will fight it later.

