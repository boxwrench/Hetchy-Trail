---
event_id: sell_the_bonds_finish_the_bore
title: Sell the Bonds, Finish the Bore
phase_id: phase_5
location_name: Coast Range Tunnel headings
mile_start: 122
mile_end: 126
historical_year_start: 1932
historical_year_end: 1934
is_fixed: true
weight: 1.0
canonical_choice: 0
hazard_kind: 
required_flags: mitchell_memorial_observed
blocked_by_flags: 
---

## Description

Active headings are running out of authorized funding. Conduct a public bond campaign, restart the crews and preserve enough surveying precision for the final breakthrough.

## Historical fact

Financial shortages temporarily suspended portions of the tunnel work. A 1932 bond issue provided additional money, and the last Coast Range Tunnel connection was made on January 5, 1934, between the Mitchell and Mocho headings.

## Source note

SFPUC 2005 history, "Coast Range Tunnel", p. 40 [SFPUC-2005]. The $6.5 million 1932 issue is listed among the seven Hetch Hetchy bond issues in "Hetch Hetchy Water Reaches San Francisco", p. 42. Design mapping: docs/Hetchy Trail Historical Game Mapping.pdf, section 5.

## Assumption note

The brief's 'on failure' outcome is modeled as the delay choice, which returns this card to the deck so the vote can be attempted again - the tunnel cannot complete without it. Historically the 1932 bonds passed.

## Choice: Campaign for the bonds

funds: 3
support: 1
readiness: 3
crew: 0
time: -2
grants: coast_range_tunnel_complete
repeat: false

The 1932 bond issue passes. Suspended headings restart, the surveys hold true, and on January 5, 1934 the Mitchell and Mocho headings meet underground.

## Choice: Delay the bond vote

funds: 0
support: 0
readiness: 0
crew: -1
time: 2
grants: 
repeat: true

The headings sit idle and crews drift to other work. The vote will have to be attempted again.

