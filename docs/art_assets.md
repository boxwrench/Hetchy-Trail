# Hetchy Trail — Suggested Art Assets

A build list for the game's visuals, tied to the current campaign and the
approved minigame roadmap. Every asset below maps to an implemented or planned
node, card, or screen — nothing here asks for a new mechanic or resource.

> **Revised 2026-07-28**, after the citation upgrade and the minigame slate
> corrections. Slot 2 is renamed, slot 4's archetype changed, slot 5's date and
> factions changed, and archival provenance got stricter. Changes are marked
> where they land rather than listed here.

Read this alongside the mapping brief's **visual-history note** (section 7):
the 1934 completion scene must depict the *temporary* ceremonial structure
built for the first-water celebration, **not** the permanent Pulgas Water
Temple, which was not finished until 1938.

> **That instruction is now in doubt, and the doubt blocks the completion art.**
> It rests on the internal brief alone. The public source the deck now cites
> describes the crowd greeting the water **"at the temple"** on 28 October 1934
> ([SOURCES.md](SOURCES.md), `[SFPUC-2005]` p. 42) — the opposite reading. One
> of the two is loose with the word, and this project cannot guess which.
> **Commission no Pulgas first-water image until the historian settles which
> structure stood that day.** It is the most reproduced scene in the game, the
> title card of the whole story, and the easiest thing here to get publicly
> wrong. Recorded as [FOLLOW-UPS.md](FOLLOW-UPS.md) H5.

---

## 1. Art Direction

**Tone (unchanged from the design):** readable, modest, warm, historical. This
is a teaching game about working people building something enormous over twenty
years. The art should feel like a well-kept archive — hand-tinted photographs,
WPA-era prints, engineering field notes — not a slick strategy UI and not a
cartoon.

**The core art-direction problem, and its answer.** You will mix two image
sources: real SFPUC archival photographs (black-and-white) and AI-generated
illustrations for the cards and moments no photo covers. Left alone, those two
clash badly. **The fix is one unifying treatment applied to everything:** a warm
duotone (sepia shadows, cream highlights) with a subtle paper grain. Real photos
and generated art both get pushed through the same duotone, so the whole game
reads as one coherent archive. This single decision is what lets an AI pipeline
and a historian's photo collection live on the same screen.

**Palette** (built to match the colors already chosen in the map code so art
and UI agree):

| Role | Hex | Used for |
|------|-----|----------|
| Aged paper / background | `#EDE4D3` | Panels, screen backgrounds |
| Sepia ink / text | `#3A322A` | Body text, line art, duotone shadows |
| Granite grey-brown | `#59544D` | Pending/unbuilt map segments, Sierra rock |
| Aqueduct amber (ochre) | `#D9A640` | Active construction, highlights, the "warm" accent |
| Water blue | `#59A6E6` | Completed segments, the Water Readiness metric |
| Delivered-water bright | `#4CCCFF` | The connected system "flowing" state |
| Warning rust | `#A6532E` | Loss states, the Mitchell Shaft memorial card |

Keep saturation low across the board; let the amber and the water-blue be the
only two colors that ever feel vivid, because they are the two things the player
is fighting to balance.

**Colour must never be the only carrier of a numeric state.** The numeral, the
label, or the icon says what is happening; hue reinforces it. This palette was
chosen for period feel and to match the map code, not for colour-vision
accessibility — granite grey-brown against sepia ink is a weak pair, and the
rust warning is not separable from the amber accent for a red-weak viewer. That
is tolerable only while colour stays redundant. Whether to move the *state*
colours onto an accessible palette is open, not decided: see
[FOLLOW-UPS.md](FOLLOW-UPS.md) P4.

**Archival photographs and interactive elements stay on separate planes.** A
photograph is evidence; a button is a game control; blending them invites the
player to read invented interaction as documentary record. Push the photo back —
low contrast or duotone — and put controls on an opaque modern surface above it,
with date, collection and identifier always visible. **Never animate people
inside a photograph, and never fake parallax that implies documentary motion.**
Full rule in [FOLLOW-UPS.md](FOLLOW-UPS.md) P2.

---

## 2. The AI-Assisted Generation Recipe

Since the pipeline is AI-assisted and solo, consistency matters more than any
single image. Use a fixed **style suffix** appended to every card/scene prompt,
and change only the subject:

> *Style suffix (paste on every prompt):* "…, 1910s–1930s American West
> construction-era illustration, warm sepia duotone, muted ochre and slate
> palette, textured like an aged lithograph print, soft paper grain, documentary
> and dignified, no text, no modern equipment, no logos."

Then apply the duotone treatment in-engine or in your image editor so even
off-style generations are pulled back into the palette. A short checklist per
generated image:

1. Subject is period-correct (no post-1934 machinery, no modern hard hats).
2. Composition leaves the top third calmer — cards render text below the image.
3. Run it through the duotone + grain treatment before import.
4. If it depicts a real place or event, sanity-check it against the card's
   `historical_fact`, and record any creative liberty in the card's
   `assumption_note` (the same discipline the text already follows).
5. Show the decision context, not the option the player is "supposed" to pick.
   Card art appears before the choice, so it should not spoil the historical
   outcome or make a debated trade look morally settled.

Fixed cards can now arrive back-to-back when a workfront crosses several
thresholds. Within each division, vary the image scale and silhouette
(establishing view, engineering detail, crew-scale view) so a two-card chain
does not read like the same photograph flashing twice.

**Archival photos always beat generated art.** Where a real SFPUC photograph
exists for a card, use it (duotoned to match) and fill the CREDITS row. Reserve
generation for the gaps.

---

## 3. Asset List by System

### 3a. Event card imagery — the biggest bucket (26 cards)

Card art resolves **by filename convention** — no engine editing required.
Drop an image at `assets/art/cards/<event_id>.png` and the card picks it up;
`<event_id>.placeholder.png` is used until final art arrives. The `event_id`
for each card is the first line of its file in `content/cards/`.

This means art and historical content are fully parallel: images are added by
dropping files in a folder, touching nothing the historian is editing. Target
one image per card. Priority subjects, grouped by division:

| Card | Suggested image | Archival photo likely? |
|------|-----------------|------------------------|
| Cut the First Road | Wagon teams grading a raw mountain road; the Canyon Ranch sawmill | Yes — SFPUC |
| Build the Railroad | A Hetch Hetchy Railroad locomotive on a timber trestle. **No coal tender** — the surviving locomotive documentation describes a fuel-oil tank | Yes — SFPUC |
| Bring the Public to the Project | Sightseers in excursion cars at a construction overlook | Yes — SFPUC |
| Power Before Water | Early Intake powerhouse interior, generators | Yes — SFPUC |
| Find Bedrock | The dam foundation excavation, diversion tunnel mouth | Yes — SFPUC |
| Twelve Faces, One Line | Miners at a tunnel heading with drills and muck cars | Yes — SFPUC |
| Protect the Reservoir, Harness the Drop | Priest Reservoir and the Moccasin penstocks descending | Yes — SFPUC |
| Sierra Snows | A snowbound camp / rotary plow (gameplay card — generate if no photo) | Maybe |
| Six Camps in the Foothills | A tidy construction camp: bunkhouses, water tank | Yes — SFPUC |
| Beat the Rising Reservoir | The Red Mountain Bar cableway over the canyon | Yes — SFPUC |
| The 803-Foot Month | A crew posed at a record-progress heading with a chalked footage board | Yes — SFPUC |
| Leave Room for Four Pipes | Surveyors staking a wide right-of-way across farmland | Generate |
| Forty-Seven Miles of Steel | A line of large steel pipe sections being welded on the valley floor | Yes — SFPUC |
| Under the San Joaquin | Pipe on timber piles in a wet river-crossing trench | Yes — SFPUC |
| Gravity or Pumps? | A drafting-table decision: tunnel profile vs. pump station (diagrammatic) | Generate |
| Crane Ridge Closes In | A squeezed timber-supported bore, gunite rings | Yes — SFPUC |
| **Mitchell Shaft Memorial** | **Restrained memorial image — a shaft headframe at dusk, no gore.** Rust accent, not amber. | Yes — SFPUC, handle with care |
| Sell the Bonds, Finish the Bore | A "Vote Yes" bond-campaign poster; the final tunnel holing-through. **Any legible date or sum must read 1932 and $6.5 million** — see §3e | Yes — SFPUC |
| Across Sunol Valley | The Alameda Creek inverted siphon pipes crossing the valley | Yes — SFPUC |
| Mud, Bay and Bridge Finance | Pipe being laid in a bay-mud trench at the shoreline | Yes — SFPUC |
| The First Drop at Pulgas | **The temporary 1934 ceremonial structure** and the crowd — NOT the 1938 Water Temple | Yes — SFPUC, verify which structure |

Handle the Mitchell Shaft card's art with the same gravity as its text: somber,
respectful, rust-toned, no sensationalism. It is a memorial, not a setback.

The five reusable hazard cards need art too. The first three also appear in
**The Heading**, so they are high-value assets rather than secondary deck
fillers:

| Hazard card | Suggested image | Treatment |
|-------------|-----------------|-----------|
| Premature Blast | Smoke, damaged drilling gear, and an abruptly emptied heading | Show consequence without an injured body or explosive spectacle |
| Rockfall in the Heading | Freshly fallen rock, abandoned tools, and a blocked work face | Environmental danger, no worker injury |
| Ground Runs Behind the Sets | A timbered heading buckled or closed by moving ground | Claustrophobic but restrained; no trapped-person depiction |
| The Board Questions the Delay | Boardroom papers, a calendar, and a sparse progress chart | Period civic pressure, not a villain caricature |
| Ratepayers Grumble | A public meeting, letters, or newspaper coverage | Show organized public concern without mocking the public |

Because hazards can recur, their images should represent a class of incident,
not a singular fatal event. Repetition must not turn worker injury into a
collectible spectacle.

### 3b. The route map (6 divisions)

The route map is now the **workfront interface**, not a decorative progress
screen. Art must keep these states legible: waiting, available, selected/active,
progress underway, progress full with events pending, and complete. Prefer one
base glyph per division plus reusable UI overlays, tints, or badges; do not
commission six raster variants of every state.

- **One background illustration** of the full Sierra-to-San-Francisco profile —
  a long horizontal panorama, mountains at left descending to the bay at right,
  in the paper/sepia palette. The interactive segment lines and progress marks
  draw on top, so keep the route corridor visually quiet.
- **Six small milestone icons**, one per division's endpoint: dam, powerhouse,
  tunnel portal, pipeline, tunnel breakthrough, Pulgas connection/first-water
  pavilion. The sixth icon must not use the permanent 1938 Water Temple.
  Simple single-color glyphs in sepia ink, ~64×64.
- **Two small reusable state marks:** a paper/card badge for "events pending"
  and a completion/flow mark. These should remain readable at map scale.
- Optional: a restrained paper-map texture (folds, survey marks, compass rose)
  as the map screen's backdrop.

### 3c. HUD and schedule cues

The HUD exposes five resource metrics plus route progress and the calendar.
Give each readout a small icon (~48×48, single-color sepia line glyphs) so the
bar reads at a glance:

| Readout | Icon suggestion |
|---------|-----------------|
| Route progress / miles | A survey chain, route line, or milestone post |
| Funds/Bonds | A bond certificate or coin stack |
| Public Support | A ribboned rosette / crowd of small figures |
| Water Readiness | A water drop filling — pairs with the water-blue |
| Crew Wellbeing | A miner's helmet with lamp, or crossed tools |
| Turn / year | A dated field-book page or surveyor's pocket watch |

Do **not** commission season emblems: seasons were deliberately removed from
the rules. Add a compact rust-colored calendar stamp or late-schedule badge for
overrun pressure, plus a small pump/recurring-cost cue. Both support information
the HUD already displays; neither introduces a new meter.

### 3d. UI chrome

- **Panel frame / nine-patch** in the aged-paper style for the EventPanel and
  HUD backdrop — a subtle letterpress border, not a heavy fantasy frame. Export
  as a nine-patch-friendly PNG so Godot can stretch it.
- **Button states** (normal / hover / pressed / disabled) — restrained, like
  stamped-ink buttons on a form.
- A soft **paper-grain overlay** texture (tiling) to lay over screens at low
  opacity for cohesion.

### 3e. Minigame visual kits

The minigames are now the project's most bespoke and shareable visual moments.
Only **The Heading** has a frozen interaction design, so commission that kit
now and keep the other four as visual budgets until their specs settle.

**All four recurring minigames are now deliberative.** The slate spans
greed/risk, deduction, spatial planning and allocation — and, since the slot 4
archetype changed, **no reflex mode at all**. That shifts the presentation
budget: what these screens need is a legible static composition that rewards
looking, not motion, speed lines or impact frames. If playtesting says the slate
feels airless, slot 4 is where a hands-on moment would come back, and its kit
would change with it — one more reason not to commission it early.

**The Heading — ready to commission**

- A tunnel-heading background and work-face layer that can accept crack,
  dust, and stress overlays.
- Drill-round, mucking, and footage/chalk-mark motifs; the target is 803 feet.
- A restrained footage gauge and escalating rock-stress treatment that remains
  readable under the paper/sepia look.
- Safe-stop and bust-state visual frames. A bust should feel like a sober
  engineering consequence, never a celebratory "you lost" flourish.
- Reuse the Premature Blast, Rockfall, and Ground Runs Behind the Sets hazard
  art where the minigame calls those incidents. Do not create gorier variants.

**Provisional kits — wait for their interaction specs**

- **Probe the Face** *(renamed 2026-07-28 — this slot was "Sound the Rock";
  "sounding" means testing rock for loose material, not drilling ahead of a
  face)*: reserve a tile language for probe holes, geological seams, sound rock,
  and bad ground. Do not finalize the grid or tile count yet. **Draw it as a
  schematic of investigating ground ahead of a heading, not as a recreation of a
  documented shift** — that crews at this heading drilled a regular forward
  probe grid is not established, so the art must not render a survey card, a
  spacing diagram, or any feet-ahead figure that would read as a reproduced
  record.
- **Forty-Seven Miles:** reserve rotatable pipe pieces and valley/bay
  terrain families, including mud and river crossings.
- **Keep the Line Open — hold the whole kit.** *(Archetype changed 2026-07-28:
  the Frogger-style lane-dodge was dropped for a loading/allocation puzzle.)*
  **Lane assets and train-in-motion sprites are now permanently out**, not
  pending — the archetype that needed them is gone. But do not start the loading
  kit either: the puzzle's premise is contradicted by our own deck and the slot
  needs a new source of tension before anything is drawn against it. When it is
  rebuilt, the cargo is what the card documents — **cement, equipment, workers
  and supplies**. Not coal (fuel-oil tank) and not imported timber (the project
  ran its own sawmills).
- **The Bond Vote — 1932, and the factions are withdrawn.** *(Corrected
  2026-07-28: this section said 1928, which was a real bond but not this card's.)*
  Every ballot, poster, tally sheet or newspaper prop must read **3 May 1932,
  $6.5 million, to finish the last five miles of the Coast Range Tunnel**. The
  earlier candidate bloc list is **withdrawn, not merely unapproved**: two of its
  five could not have voted on a San Francisco municipal bond at all. Commission
  **no faction panels, emblems, or portraits** — and note that the screen's whole
  shape is in question, since one of the two live options replaces bargaining
  with five institutions by assembling a case from documented public concerns.
  Period civic ephemera as a *texture* is safe; a named constituency is not.

### 3f. Title and end screens

- **Title art** (1280×720): a wide, hopeful establishing image — the empty
  route the player is about to build, or O'Shaughnessy Dam under construction —
  with room for the "Hetchy Trail" wordmark.
- **One grade-aware completion family.** The game distinguishes
  `ahead_of_history`, `matched_history`, and `behind_history`; a single dated
  ceremony image cannot honestly represent all three. Use either three related
  treatments, or a neutral first-water image shared by every grade with the
  temporary 1934 ceremony used only for `matched_history`. Never substitute the
  permanent 1938 Water Temple.
- **Four loss images** for `bond_crisis`, `project_cancelled`, `work_halted`,
  and `city_moves_on`. They should be quiet and melancholic, not punishing — an
  idle heading, an empty camp — matching the warm tone.

Overrun pressure is not a new loss condition and does not need its own end
screen.

### 3g. Typography

- One **display/title face** with a period feel (a warm slab-serif or
  early-20th-century poster type) for headings and the wordmark.
- One **highly readable body face** for card text and the teaching layer —
  legibility first, since this is where the history is taught.
- Put font files in `assets/fonts/` and note their licenses (embeddable, ideally
  open — e.g. an SIL Open Font License face) the same way archival images get a
  credit row.

---

## 4. Technical Specs (Godot 4.7)

- **Format:** PNG for art with transparency (icons, frames, cards); JPG or
  duotoned PNG acceptable for full-bleed photos where alpha isn't needed.
- **Card images:** target ~880×495 (16:9) so they fill the EventPanel's 640-wide
  column with headroom; the panel scales them to fit.
- **Icons:** 48×48 (HUD) and 64×64 (map milestones), transparent PNG.
- **Screens:** author at 1280×720 (the project's base viewport) or a 2× multiple.
- **Import:** in the editor, set pixel-art-free textures to **Filter = Linear**
  (the default) and enable mipmaps for anything that scales down (map panorama,
  card photos). Small crisp icons can use **Filter = Nearest** if they look soft.
- Keep source/editable files (layered, full-res) **out of the shipping folders**
  — a `art_source/` sibling or an external drive — so `assets/` stays lean.

---

## 5. Archival Photo Workflow (SFPUC materials)

**Where to look first.** Every card's `## Source note` now names a section and a
printed page of the SFPUC 2005 history — see [SOURCES.md](SOURCES.md). That
section is the natural starting point for a photo request: it is the passage the
card was built from, so a photograph illustrating it will match the card's text
rather than a neighbouring event. Quote the printed page when asking, and mind
the offset — in the linked PDF the printed page sits four pages later than the
PDF counter.

When the SFPUC historian provides images:

1. Drop the file in `assets/art/archival/`.
2. **Add its row to [assets/art/archival/CREDITS.md](../assets/art/archival/CREDITS.md)
   before it ships** — file, subject, date, source/archive, and rights. This is a
   hard rule already baked into the repo.

   **Before the first image lands, settle the wider row** — `source_url`,
   `licence`, `licence_url`, `downloaded_utc`, `modifications`,
   `in_game_locations`, `archive_collection_id` ([FOLLOW-UPS.md](FOLLOW-UPS.md)
   P1). The table is still empty, which is the only cheap moment to widen it;
   retrofitting provenance onto images already in the tree is the expensive
   version. Four rights traps worth knowing while you collect: **"no known
   restrictions" is not CC0**, **"royalty-free" is not a licence**, **an image
   inside an agency PDF carries no reuse right**, and **a repository's MIT
   licence never clears its bundled art.**
3. Duotone it to the palette so it sits with the generated art.
4. Name the file `<event_id>.png` and place it in `assets/art/cards/`. There is
   no Inspector step — the card finds it by name. Godot does have to import the
   file first, so either open the project in the editor once, or run
   `godot --headless --import`. Until it is imported, the card shows no image.
5. If you crop, retouch, or colorize, note that in the card's `assumption_note`
   — the visual record gets the same honesty as the factual text.

Confirm with the historian **which structure appears** in any Pulgas
first-water photo (temporary 1934 pavilion vs. the 1938 permanent temple) so the
completion scene stays accurate. As of 2026-07-28 this is a **blocker, not a
courtesy check** — the internal brief and the cited public source disagree on the
word "temple". See the note at the top of this file and
[FOLLOW-UPS.md](FOLLOW-UPS.md) H5.

---

## 6. Suggested Build Order (mapped to the roadmap)

Art is not on the critical path to the playable campaign, but it is central to
the minigame artifact and the release presentation. Slot it in like this:

| When | Assets | Why then |
|------|--------|----------|
| Now / before P2 | Approve the duotone treatment with 3–4 card proofs: one archival photo, one generated event, and at least one reusable hazard; prove the map-state glyphs and schedule cue | Locks the visual grammar before bulk production |
| Alongside P2 | The Heading visual kit plus the three physical-hazard images it reuses | Supports the one minigame whose interaction is designed |
| Alongside P3 | Build each remaining minigame kit only after that slot's interaction spec freezes. **Probe the Face and Forty-Seven Miles first; Keep the Line Open and The Bond Vote last** | Avoids commissioning assets for a discarded puzzle archetype — which has already happened once, to the lane-dodger. Slots 4 and 5 need design decisions before a spec can freeze at all |
| M4 release pass | Title art, grade-aware completion treatment, four loss screens, UI chrome/fonts, full 26-card set, map panorama and milestone icons | Finishes the campaign presentation once content and screens are stable |
| With SFPUC delivery | Archival photos swapped in for generated placeholders, credits filled | Real photos replace stand-ins card by card |

Do not bulk-generate 26 placeholders before the visual treatment is approved.
The EventPanel already collapses cleanly when art is absent. Prove the look with
a small representative set, then fill cards division by division, replacing
stand-ins with credited archival photographs whenever they arrive.

> **Boundary note:** every asset above attaches to an implemented or approved
> node, card, or screen. If a proposed image seems to need a new mechanic,
> meter, or faction to justify it, it's out of scope — cut it, not the design.
