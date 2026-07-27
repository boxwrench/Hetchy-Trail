---
event_id: power_before_water
title: Power Before Water
phase_id: phase_2
location_name: Early Intake
mile_start: 8
mile_end: 33
historical_year_start: 1917
historical_year_end: 1918
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: high_sierra_access_complete
blocked_by_flags: 
---

## Description

Build local generation before expanding round-the-clock drilling. The initial delay produces faster tunnel work and limited revenue during later construction.

## Historical fact

Construction of Early Intake Powerhouse began in 1917. Generation began in May 1918, supplying electricity east to the dam site and west toward Moccasin. Surplus electricity was also sold commercially.

## Source note

SFPUC historical materials, summarized in docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

The brief's 'then Time -2 across Mountain Tunnel cards' is consolidated into the Mountain Tunnel card's canonical choice. Construction power is a prerequisite flag for tunnel and dam work.

## Choice: Build the powerhouse first

funds: -2
support: 1
readiness: 1
crew: 0
time: 1
grants: construction_power_available
repeat: false

Early Intake begins generating in May 1918. Electricity flows east to the dam site and west toward Moccasin, and surplus power earns the city a little revenue.

