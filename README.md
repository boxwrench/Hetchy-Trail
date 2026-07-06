# Hetchy Trail

A 2D historical resource-management game for Godot 4.7, inspired by The Oregon
Trail. The player builds the 167-mile Hetch Hetchy aqueduct from the Sierra
Nevada to San Francisco (1914-1934), balancing five metrics: Funds/Bonds,
Public Support, Water Readiness, Crew Wellbeing, and Time/Season.

Hetchy Trail is a teaching game. Every encounter card carries the historical
fact behind it, a source note, and an assumption note recording where gameplay
deviates from the record.

## Getting started

1. Open the repository folder in Godot 4.7 (the `project.godot` file is
   committed; the editor will import everything on first open).
2. The two autoload singletons (`GameState`, `EventManager`) are registered in
   `project.godot`.
3. Read `docs/technical_design.md` for the full architecture, and
   `docs/Hetchy Trail Historical Game Mapping.pdf` for the historical research
   the campaign data is built from.

## Layout

- `autoload/` - GameState and EventManager singletons (all game logic)
- `resources/` - custom Resource classes (EventCard, EventChoice, RouteSegment)
- `data/events/` - the encounter deck, one `.tres` per historical event
- `data/segments/` - the six construction divisions of the route
- `scenes/` - main, journey, map, and UI scenes (in progress)
- `assets/art/archival/` - SFPUC archival photographs, with credits
- `docs/` - design documents and historical research
