# Hetchy Trail — Suggested Art Assets

A build list for the game's visuals, tied to the systems that already exist in
[technical_design.md](technical_design.md). Every asset below maps to a node,
a card, or a screen the code already references — nothing here asks for a new
mechanic or resource.

Read this alongside the mapping brief's **visual-history note** (section 7):
the 1934 completion scene must depict the *temporary* ceremonial structure
built for the first-water celebration, **not** the permanent Pulgas Water
Temple, which was not finished until 1938.

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

**Archival photos always beat generated art.** Where a real SFPUC photograph
exists for a card, use it (duotoned to match) and fill the CREDITS row. Reserve
generation for the gaps.

---

## 3. Asset List by System

### 3a. Event card imagery — the biggest bucket (21 cards)

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
| Build the Railroad | A Hetch Hetchy Railroad locomotive on a timber trestle | Yes — SFPUC |
| Bring the Public to the Project | Sightseers in excursion cars at a construction overlook | Yes — SFPUC |
| Power Before Water | Early Intake powerhouse interior, generators | Yes — SFPUC |
| Find Bedrock | The dam foundation excavation, diversion tunnel mouth | Yes — SFPUC |
| Twelve Faces, One Line | Miners at a tunnel heading with drills and muck cars | Yes — SFPUC |
| Protect the Reservoir | Priest Reservoir and the Moccasin penstocks descending | Yes — SFPUC |
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
| Sell the Bonds, Finish the Bore | A "Vote Yes" bond-campaign poster; the final tunnel holing-through | Yes — SFPUC |
| Across Sunol Valley | The Alameda Creek inverted siphon pipes crossing the valley | Yes — SFPUC |
| Mud, Bay and Bridge Finance | Pipe being laid in a bay-mud trench at the shoreline | Yes — SFPUC |
| The First Drop at Pulgas | **The temporary 1934 ceremonial structure** and the crowd — NOT the 1938 Water Temple | Yes — SFPUC, verify which structure |

Handle the Mitchell Shaft card's art with the same gravity as its text: somber,
respectful, rust-toned, no sensationalism. It is a memorial, not a setback.

### 3b. The route map (6 divisions)

The map (plan Task 8) currently draws divisions as colored lines that light up.
Art can enrich it without changing that logic:

- **One background illustration** of the full Sierra-to-San-Francisco profile —
  a long horizontal panorama, mountains at left descending to the bay at right,
  in the paper/sepia palette. The lit-segment lines draw on top.
- **Six small milestone icons**, one per division's endpoint: dam, powerhouse,
  tunnel portal, pipeline, tunnel breakthrough, water temple/bay. Simple
  single-color glyphs in sepia ink, ~64×64.
- Optional: a paper-map texture (folds, coffee-ring, compass rose) as the map
  screen's backdrop.

### 3c. HUD — the five metrics

The HUD (plan Task 4) is text-only today. Give each metric a small icon
(~48×48, single-color sepia line glyphs) so the bar reads at a glance:

| Metric | Icon suggestion |
|--------|-----------------|
| Funds/Bonds | A bond certificate or coin stack |
| Public Support | A ribboned rosette / crowd of small figures |
| Water Readiness | A water drop filling — pairs with the water-blue |
| Crew Wellbeing | A miner's helmet with lamp, or crossed tools |
| Time/Season | A four-quarter seasonal ring or a pocket watch |

Also useful: four tiny season emblems (winter/spring/summer/fall) for the date
readout, in the same line-glyph style.

### 3d. UI chrome

- **Panel frame / nine-patch** in the aged-paper style for the EventPanel and
  HUD backdrop — a subtle letterpress border, not a heavy fantasy frame. Export
  as a nine-patch-friendly PNG so Godot can stretch it.
- **Button states** (normal / hover / pressed / disabled) — restrained, like
  stamped-ink buttons on a form.
- A soft **paper-grain overlay** texture (tiling) to lay over screens at low
  opacity for cohesion.

### 3e. Title and end screens

- **Title art** (1280×720): a wide, hopeful establishing image — the empty
  route the player is about to build, or O'Shaughnessy Dam under construction —
  with room for the "Hetchy Trail" wordmark.
- **Five end-screen images**, one per outcome the Main scene already handles
  (plan Task 9): `system_complete` (the 1934 ceremony — temporary structure),
  `bond_crisis`, `project_cancelled`, `work_halted`, `city_moves_on`. The four
  loss images should be quiet and melancholic, not punishing — an idle heading,
  an empty camp — matching the warm tone.

### 3f. Typography

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

When the SFPUC historian provides images:

1. Drop the file in `assets/art/archival/`.
2. **Add its row to [assets/art/archival/CREDITS.md](../assets/art/archival/CREDITS.md)
   before it ships** — file, subject, date, source/archive, and rights. This is a
   hard rule already baked into the repo.
3. Duotone it to the palette so it sits with the generated art.
4. Name the file `<event_id>.png` and place it in `assets/art/cards/`. No
   editor step is needed — the card finds it by name.
5. If you crop, retouch, or colorize, note that in the card's `assumption_note`
   — the visual record gets the same honesty as the factual text.

Confirm with the historian **which structure appears** in any Pulgas
first-water photo (temporary 1934 pavilion vs. the 1938 permanent temple) so the
completion scene stays accurate.

---

## 6. Suggested Build Order (mapped to the roadmap)

Art is not on the critical path to a playable loop — the game runs on
programmer-drawn shapes through M3. Slot art in like this:

| When | Assets | Why then |
|------|--------|----------|
| Alongside M1–M2 (loop + map) | The duotone treatment decision; 3–4 test card images; the 5 HUD icons | Locks the look early on the cheapest surfaces |
| After M3 (screens exist) | Title art, the 5 end-screen images, UI frame + buttons, fonts | Now there are screens to hold them |
| M4→M5 (balance → content) | The full 21-card image set, map panorama + milestone icons, paper overlay | Bulk art once the game is proven fun |
| With SFPUC delivery | Archival photos swapped in for generated placeholders, credits filled | Real photos replace stand-ins card by card |

Start every card with a generated placeholder so the EventPanel is never empty;
replace with the archival photograph whenever one arrives. The game stays
shippable at every step, and the archive fills in over time.

> **Boundary note:** every asset above attaches to an existing node, card, or
> screen. If a proposed image seems to need a new mechanic, meter, or faction to
> justify it, it's out of scope — cut it, not the design.
