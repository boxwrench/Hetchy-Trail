# Follow-ups

Open items that are real but not scheduled. Each says what it is, why it matters,
and how much work it is — so a future session can pick one up without
re-deriving the reasoning.

**Nothing here is a decision that has been made.** These are things noticed and
deliberately deferred.

Most of this list came out of an external research review of the five minigame
slots (July 2026). The minigame findings live with the slot designs; what landed
here is everything in that review that turned out to be about the game as a
whole rather than about a minigame.

---

## For the historian

These go out as one packet. Sending three separate asks wastes goodwill.

### H1 — Citation gaps in four cards

Recorded in full in [SOURCES.md](SOURCES.md), "Open items for the historian".
The Canyon Ranch sawmill date and 4.5-mile distance, the 17 July 1931 Mitchell
Shaft explosion date, the exact day in February 1934 for Alameda Creek Siphon
No. 1, and the 10:12 a.m. time for the first water at Pulgas.

Each claim may well be correct — it simply is not in the pages of the SFPUC 2005
history that were read. The internal brief presumably drew them from somewhere,
and that somewhere is what we need.

**Effort: small.** Four page references.

### H2 — Card 03 may price passenger service backwards

[03_railroad_excursions.md](../content/cards/03_railroad_excursions.md) treats
the public excursion as a pure cost (`funds: -1`, `support: +2`). The SFPUC 2005
history, p. 32, records that passengers paid 7½ cents per mile, and external
research reports the railroad ran as a common carrier from July 1918 to February
1925 charging 12.5 cents per ton-mile, carrying mail and passengers.

If passenger service was closer to revenue-neutral, the card's economics teach
the wrong thing about how the project sustained itself.

**Effort: small to answer, small to change.** But it is a content change, so it
is the historian's call, not a tuning decision.

### H3 — Crane Ridge: firmer grounds for the existing rejection

The [schedule-for-resilience matrix](superpowers/specs/2026-07-28-historian-review-schedule-trades.md)
rejects Crane Ridge as a candidate, arguing from the data model: gunite must not
cost more overall than the timber failure, so the card cannot honestly become a
net trade.

The research review puts the timber-versus-gunite question on **hold** for a
different and better reason — the exact support material, terminology and date at
that heading are not established at all. Same verdict, firmer footing.

**Effort: small.** Amend the matrix entry before the packet goes out.

### H4 — Does the deck need to address the valley?

**The largest open question in the project, and the only one on this page that
could change what the game is.**

`content/` contains no mention of Muir, the Sierra Club, the Raker Act, or the
flooding of Hetch Hetchy Valley. The single occurrence of "valley floor" is a
bedrock boring at the dam site.

There is a defensible reason: the campaign opens in 1914, after the Raker Act,
so the fight is settled before turn one. But that scope choice is not stated
anywhere, which means it currently reads as an omission rather than a decision.
The game is about building the aqueduct that drowned the valley, and it ships
from the agency that drowned it.

The American Historical Association's
[standards for museum exhibits](https://www.historians.org/resource/standards-for-museum-exhibits-dealing-with-historical-subjects/)
are explicit that contested history should be engaged rather than routed around.
A showcase piece that silently skips its own controversy invites exactly the
reading it is trying to avoid.

Options, roughly in ascending cost: a stated scope note in `content/`; a framing
card before turn one; an epilogue. **The choice belongs to the project owner and
the historian together.**

**Effort: the decision is the expensive part.** Any of the three is cheap to
build once made.

---

## Content opportunities noticed while verifying citations

Not defects. Things the sources contain that the deck currently does not use.

### C1 — The ending is stronger than the deck's ending

The SFPUC 2005 history, p. 38, notes the San Joaquin pipelines were built "over a
period of 37 years", that O'Shaughnessy's 100-foot right of way left room for
four parallel lines, and that **the fourth bore has still not been built** more
than 70 years later.

That is the payoff for
[Leave Room for Four Pipes](../content/cards/12_room_for_four_pipes.md) — the
foresight the card asks the player to pay for, vindicated across a lifetime. The
game ends in 1934 and never collects it.

An epilogue beat would also let the game say honestly that 1934 was not the end
of the work: Bay Crossing Pipeline No. 2 ran 1934–1936, the dam was raised in
1938.

### C2 — Two end-of-game facts worth using

- **Just over $100 million, met solely by the city, without State or Federal
  assistance** (p. 31).
- **Seven bond issues over 24 years totalling nearly $102 million** (p. 42):
  $600,000 and $45 million in 1910, $10 million in 1924, $24 million in 1928,
  $6.5 million in 1932, then $3.5 million and $12.1 million.

The financing arc is a teaching point the deck gestures at but never totals up.

---

## Project hygiene

### P1 — Provenance schema for archival images

[CREDITS.md](../assets/art/archival/CREDITS.md) has File / Subject / Date /
Source / Rights. The research review recommends a fuller row: `source_url`,
`licence`, `licence_url`, `downloaded_utc`, `modifications`,
`in_game_locations`, `archive_collection_id`.

**Do this while the table is still empty.** Retrofitting provenance onto images
already in the tree is the expensive version.

Rights hard-stops worth writing down alongside it, because they are easy to get
wrong: "no known restrictions" is not CC0; "royalty-free" is not a licence; an
image inside an agency PDF carries no reuse right; a repository's MIT licence
never clears its bundled art.

### P2 — Display rules for archival photographs

Evidence and interaction should stay on separate planes: archival image at low
contrast or duotone, interactive elements on an opaque modern surface, date and
collection and identifier always shown. **Never animate people inside a
photograph**, and never manufacture parallax that implies documentary motion.

Relevant the moment the first image lands, which is why it is written down now.

### P3 — Godot's MIT notice in distributed builds

[LICENSE](../LICENSE) and [README](../README.md) handle our code and third-party
assets well — the scope carve-out is explicit. What is not addressed is that the
engine's own MIT notice must accompany a distributed build.

**Effort: small.** Confirm what the export template already includes before
adding anything.

### P4 — Colour accessibility for numeric states

The Okabe–Ito palette is the standard choice for colour-vision accessibility:
`#000000`, `#E69F00`, `#56B4E9`, `#009E73`, `#F0E442`, `#0072B2`, `#D55E00`,
`#CC79A7`. Numerals should carry the meaning and colour should be redundant, not
the code.

Whole-game, not one screen — it applies anywhere the UI distinguishes states by
hue.

### P5 — Claim-status labels in `assumption_note`

Every card has an `assumption_note` in free prose, so triaging 26 cards means
reading 26 cards. A status label — `verified` / `defensible abstraction` /
`provisional` / `composite` — would let a historian sort the deck in one pass and
spend their time on the soft claims.

**Effort: medium.** It touches every card and the import schema, so it wants a
plan rather than an afternoon.

### P6 — Two stale slot references left deliberately

[art_assets.md](art_assets.md) still calls slot 2 "Sound the Rock" and reserves
budget against the old slot 4 archetype. **Left untouched on purpose:** that file
has substantial uncommitted work in the tree from an earlier session, and
sweeping it into an unrelated commit is how work-in-progress gets lost.

Fix it when that work lands, not before. Its guidance is already conservative —
it says not to commission train or lane assets until the archetype settles — so
nothing is being built against the stale name.

The slot files under `specs/minigames/` also keep their old filenames, which the
spec notes so the paths still resolve.

### P7 — First-play acceptance tests apply to the game as it stands

The research review proposes gates that do not need any minigame to exist:
a first-time player acts within 8 seconds of gaining control without spoken
help; can say what their action changed after 30 seconds; can name what is at
risk before a consequential decision; no moderator explains a rule, and a
confused action counts as a design failure.

Worth running against the current card loop **before** five more screens are
built on top of it.

---

## Checked and clean — do not redo

- **No card puts invented speech in the mouth of a named historical person.**
  Audited 2026-07-28 across all 26 cards. O'Shaughnessy appears only as the name
  of the dam. The research review flags this as a standing risk for history
  products; the deck is currently clean, and should stay that way.
- **The licence scope carve-out is already correct.** README states the MIT
  grant covers software only and that fonts, audio and artwork carry their own
  licences. No gap here.
