---
event_id: hetch_hetchy_railroad
title: Build the Railroad
phase_id: phase_1
location_name: Hetch Hetchy Junction to the mountain project
mile_start: 0
mile_end: 20
historical_year_start: 1915
historical_year_end: 1917
is_fixed: false
weight: 3.0
canonical_choice: 0
hazard_kind: 
required_flags: high_sierra_access_complete
blocked_by_flags: 
---

## Description

Spend heavily now to remove recurring freight delays. An operational railroad keeps supplies moving through winters that block the mountain roads.

## Historical fact

The city constructed a 68-mile standard-gauge railroad from Hetch Hetchy Junction to the mountain project. It was completed in 1917 and carried cement, equipment, workers and supplies. It operated in winter when mountain roads could be blocked by snow.

## Source note

SFPUC 2005 history, "Design Decisions / Groveland Headquarters", p. 31 [SFPUC-2005]. Also NPS, "Encroaching Civilization - Dams and Trains" [NPS-YOSE]. Design mapping: docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

Historically the railroad was built; declining it is a gameplay counterfactual. Without the railroad_operational flag, winter build rates in Sierra segments collapse and the Sierra Snows card stays in the deck.

## Choice: Build the railroad

funds: -3
support: 0
readiness: 0
crew: 1
time: -2
grants: railroad_operational
repeat: false

Sixty-eight miles of standard gauge climb toward the dam site. Cement, machinery, and workers now move in any season.

## Choice: Rely on mountain roads

funds: 0
support: 0
readiness: 0
crew: 0
time: 1
grants: 
repeat: false

The money stays in the treasury, but every winter storm can now close the only way in.

