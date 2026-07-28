# Editing Hetchy Trail card content

Every encounter in the game is one file in `cards/`. You can edit them in any
text editor. You do not need to install or understand the game engine.

## What a card file looks like

The block between the two `---` lines holds the card's settings. Below it,
each `## Heading` starts a section of writing.

- **Description** — what the player is told is happening, before they choose.
- **Historical fact** — what actually happened. Shown after the player chooses.
- **Source note** — where the fact comes from.
- **Assumption note** — anywhere the game departs from the record. **Every
  departure must be recorded here.** This is a hard project rule.
- **Choice: <name>** — one option the player can pick. The lines beginning
  `funds:`, `support:`, `readiness:`, `crew:`, `time:`, `grants:` and `repeat:`
  are the game effects; the paragraph underneath is what the player reads after
  picking it.

## Safe to change freely

All the prose: titles, descriptions, historical facts, source notes, assumption
notes, choice names, and outcome paragraphs. Fix wording, correct facts, add
detail — none of it can break the game.

## Change only with the developer

`event_id`, `grants:`, `required_flags`, `blocked_by_flags`, `hazard_kind`,
and `canonical_choice`. These wire the card into the rest of the campaign, and
a wrong value will stop the game building.

The number effects (`funds:`, `crew:` and so on) run from -5 to +5, where 1 is
minor, 2 substantial, 3 severe. Adjusting these changes game balance, so tell
the developer when you do.

## A note on seasons

The game advances in construction phases, not calendar seasons. Card writing
may mention winter, snow or heat for atmosphere, but the game does not simulate
weather, and the timing of those mentions is not exact. This is recorded in the
affected cards' assumption notes.

## Applying your edits

The developer runs one command to rebuild the game's data from these files:

    godot --headless res://tools/import_cards.tscn

If anything in a file is malformed, that command stops and names the file and
line, so a mistake is always caught rather than silently ignored. It will
refuse to build if you:

- misspell an effect name (`fund:` instead of `funds:`)
- misspell or invent a frontmatter key
- add a section heading that is not one of the four above or `## Choice: <name>`
- give an effect a number outside -5 to +5, or something that is not a number
- reuse an `event_id` that another card already has
- require a flag that no card ever grants

You cannot break the game by editing prose. The build step catches everything
else before it reaches the game.
