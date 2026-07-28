---
event_id: room_for_four_pipes
title: Leave Room for Four Pipes
phase_id: phase_4
location_name: Oakdale Portal to Tesla Portal right-of-way
mile_start: 49
mile_end: 97
historical_year_start: 1930
historical_year_end: 1931
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: 
blocked_by_flags: 
---

## Description

Acquire more land than Pipeline No. 1 immediately requires. The larger purchase reduces current funds but creates future expansion capacity.

## Historical fact

The city obtained a right-of-way approximately 100 feet wide, providing room for as many as four parallel San Joaquin pipelines.

## Source note

SFPUC 2005 history, "San Joaquin Pipelines", p. 38 [SFPUC-2005]. Design mapping: docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

The brief's 'permanent Expansion Capacity +2' is recorded as the row_expansion_secured flag and acknowledged in the end-of-game summary rather than tracked as a sixth live resource.

## Choice: Buy the full hundred-foot corridor

funds: -2
support: 0
readiness: 1
crew: 0
time: 0
grants: row_acquired, row_expansion_secured
repeat: false

The city acquires room for four parallel pipelines across the valley. Only one will be built now, but the corridor will serve San Francisco for a century.

## Choice: Buy only what Pipeline No. 1 needs

funds: -1
support: 0
readiness: 0
crew: 0
time: 0
grants: row_acquired
repeat: false

A narrower strip saves money today. Any future pipeline will have to negotiate the valley all over again.

