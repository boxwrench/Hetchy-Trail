---
event_id: gravity_or_pumps
title: Gravity or Pumps?
phase_id: phase_5
location_name: Tesla Portal
mile_start: 97
mile_end: 126
historical_year_start: 1927
historical_year_end: 1927
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: 
blocked_by_flags: 
---

## Description

Make the project's defining long-term decision. The gravity tunnel is slower and more expensive to construct, while the debated pumped alternative would provide less capacity and continuing operating costs. Only the gravity option follows the completed historical system.

## Historical fact

Construction of the 28.5-mile Coast Range Tunnel was delayed until 1927. A pumped pipeline was discussed as an alternative, but the gravity tunnel offered greater capacity without permanent pumping costs.

## Source note

SFPUC historical materials, summarized in docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

The pumped alternative's recurring cost is implemented as an extra funds point every winter (the pumped_alternative_chosen flag), approximating the brief's 'Funds -1 during every later operating chapter.'

## Choice: Commit to the gravity tunnel

funds: -3
support: 0
readiness: 3
crew: 0
time: 2
grants: coast_range_committed, gravity_tunnel_chosen
repeat: false

Twenty-eight and a half miles of bore through the Coast Range: slower and costlier to build, but water will flow to the city by gravity alone, forever.

## Choice: Build the pumped pipeline instead

funds: -2
support: 0
readiness: 1
crew: 0
time: -1
grants: coast_range_committed, pumped_alternative_chosen
repeat: false

A cheaper, faster line over the hills - with less capacity and pumping bills the city will pay every year it operates.

