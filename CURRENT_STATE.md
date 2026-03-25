# ol-factory — Current Game State

This document describes the game as it exists right now — intended as a briefing for brainstorming or agent handoff.

---

## Scenes

| Scene | Contents |
|-------|----------|
| **Outside** | Stone path, gatherable ingredient bushes/trees, shop counter, skunk companion |
| **Lab** | Mixing bench, processor, display shelf, request board, doors to outside and cellar |
| **Cellar** | Aging rack |

Scene transitions are instant, triggered by walking into a Door node (Area2D). SceneManager is an autoload that handles them.

---

## Full Game Loop

### 1. Gather raw ingredients
- Gatherable plants are `Interactable` nodes (Area2D, collision layer 2) in the outside/lab scenes
- Walk up and press **E** to collect — the plant tweens to zero and "+1 [Name]" floats up
- Raw ingredients are stored in `InventoryManager` (persisted to `user://save_data.json`)
- Plants auto-respawn when the player re-enters a scene

### 2. Process raw → oil
- Interact with the **processor** (lab scene) to open the processor UI
- Raw ingredients in inventory are listed; each has a "Process" button
- Costs **5 coins** per batch, consumes the raw ingredient immediately
- Takes **60 seconds of play time** to complete (tracked by CellarManager.play_time)
- Finished oils sit in a "ready" queue until collected; collecting adds them to inventory
- Processor intro state (`has_met_processor`) is tracked — unused in code but saved, available for a tutorial moment
- All state persisted to `user://processing_data.json`

### 3. Mix a blend
- Interact with the **mixing bench** (lab scene) to open the 3-column mixing UI
- **Left column**: ingredient grid (oils only — raws filtered out by checking `result_item`) + discovered accords below
  - Ingredients shown with count badge; disabled when 0 available or after committing
  - Tab buttons filter by note position (all / top / middle / base)
  - Accords shown as single-click units that expand to their component oils in the blend
- **Middle column**: live preview
  - Beaker (custom-drawn `BeakerDisplay`) with fill color blended from ingredient `liquid_color` values
  - Balance bar showing how evenly distributed the blend is
  - Top / Mid / Base note indicators (lit up when the blend covers that position)
  - Auto-generated description text
- **Right column**: blend list + quality readout
  - Lists each ingredient and accord with drop counts
  - Quality score (0–10), tier label, compatibility %, balance hint, pyramid bonus indicator
  - **Commit** button — finalises, consumes ingredients from inventory, creates a `BottledPerfume`
  - **Clear** button — resets without consuming anything
- On commit, AccordManager checks the blend for newly discovered accords
  - If one is found, a discovery card pops up (stays until the player clicks **OK**)
  - If multiple are found they queue up one at a time

### 4. Age a bottle (optional)
- Interact with the **cellar rack** (cellar scene)
- Up to 5 slots by default; player can buy up to 2 extra slots at the shop (50 coins each, max 7 total)
- Placing a bottle starts the aging clock; aging uses `CellarManager.play_time` (accumulated game seconds, not wall time)
- Gain **+0.25 quality per 120 seconds**, capped at **+1.5**
- Retrieve at any time — early retrieval locks in the partial bonus
- Fully aged bottles flag `aged = true` and store the final `age_bonus`
- Rack state persisted to `user://cellar_data.json`

### 5. Use finished bottles
Three destinations for a finished `BottledPerfume`:

**Sell (shop, outside)**
- Two tabs: Sell and Buy
- Sell tab: lists all carried bottles with calculated price
  - Base prices by tier: Poor=3, Decent=12, Good=40, Excellent=100
  - Aging multiplier: up to 1.5× at full age cap
- Buy tab: purchase oil bundles (3× per buy) priced by intensity bracket (15/20/25 coins), and extra rack slots (50 coins each)

**Fulfill a request (request board, lab)**
- One active request shown at a time, from a tiered pool (tiers 1–4)
- Request board has a "!" indicator when the current request is unseen
- Player selects any carried bottle and clicks Deliver
- `BottledPerfume.matches_request()` checks: required scent families (drop minimums), required note positions, minimum quality, whether an accord is used, whether it's been aged
- **Failure**: feedback shown, bottle NOT consumed
- **Success**: celebratory popup with NPC name/personality, reward granted, request marked complete
- Rewards: coins (`reward_amount`), bonus ingredient drops (`reward_ingredient_path` + `reward_ingredient_amount`), or hint text
- Tier advances after 2 completions at the current tier (up to tier 4)
- Request rotates to a different same-tier request after 4 uncommitted blends
- State persisted to `user://request_data.json`

**Display on shelf (display shelf, lab)**
- Up to 6 display slots as trophies
- On placing: naming overlay appears — player can type a custom name or skip
- Displayed bottles show as colored beaker icons in a horizontal row with the name below
- Can be un-displayed (returned to inventory)
- Display state persisted in `user://cellar_data.json`

---

## Quality Formula

```
quality = clamp(avg_pairwise_compat * 10 * balance_modifier + pyramid_bonus, 0, 10)
final_quality = clamp(quality + age_bonus, 0, 10)
```

- **Compatibility**: average of `ScentCompatibility.get_compatibility(family_a, family_b)` across all unique ingredient pairs. Same family = 1.0. Default = 0.3. Lookup table in `scent_compatibility.gd`.
- **Balance modifier**: 1.0 normally. Penalised when one ingredient's weighted fraction > 50%: `clamp(1.0 - (max_frac - 0.5) * 1.4, 0.3, 1.0)`.
- **Pyramid bonus**: +0.5 if the blend has at least one top, one middle, and one base note ingredient.
- **Aging bonus**: 0.0–1.5 added after mixing (locked on retrieval from rack).

Tiers: **Poor** < 3 / **Decent** < 5.5 / **Good** < 7.5 / **Excellent** ≥ 7.5

---

## Accords

7 discoverable accords stored in `data/accords/*.tres` as `BaseAccord` resources.

Candy Cane, Garden Path, Twilight Woods, Enchanted Grove, Warm Embrace, Morning Dew, Rose Garden Tea.

- Recipes are `{ ingredient_resource_path: min_drops }` dictionaries
- Discovery requires **exact ingredient match** (no extras allowed) with drop counts meeting minimums
- Discovered accords appear in the mixing bench ingredient grid as clickable units
- Discovery is permanent and persisted to `user://accord_data.json`
- Accord usage is tracked on bottles (`has_accord = true`) and can be required by requests (`requires_accord`)

---

## Ingredients

### Raw (gatherable, must be processed before mixing)

| Ingredient     | Family  | Note   | Intensity | Gatherable scene | Icon? |
|----------------|---------|--------|-----------|-----------------|-------|
| Raw Rose       | floral  | middle | 6         | Outside         | No    |
| Raw Jasmine    | floral  | middle | 7         | Outside         | No    |
| Raw Cinnamon   | spicy   | middle | 7         | Outside         | Yes   |
| Raw Cedar      | woody   | base   | 5         | Lab             | No    |
| Raw Sandalwood | woody   | base   | 6         | Lab             | No    |
| Raw Vanilla    | sweet   | base   | 7         | Outside         | No    |
| Raw Peppermint | green   | top    | 8         | Outside         | No    |
| Raw Bergamot   | citrus  | top    | 5         | Outside         | No    |

### Processed Oils (appear in mixing bench)

All 8 have a corresponding `.tres` in `data/oils/`. Oils do not have icons — color dots are used instead.

---

## NPC Requests

13 requests in `data/requests.json` across 4 tiers, attributed to 8 active NPCs in `data/npcs.json`.

| NPC | Personality | Tier(s) | Requests |
|-----|-------------|---------|----------|
| Charlotte | romantic / floral | 1, 2 | Flower Power, Heart Strings |
| Rémy | outdoorsy / green | 1, 3 | A Fresh Start, Twilight Walk |
| Geneviève | nostalgic / woody | 1, 2, 4 | Woody Warmth, Deep Roots, The Legacy Blend |
| Noëlle | sweet-natured / sweet | 1, 4 | Sweet Tooth, Sweet Symphony |
| Margot | picky / floral | 3 | Garden Party |
| Pierre | practical / citrus | 2 | Morning Lift |
| Simone | dramatic / sweet | 4 | Enchanted Evening |
| Bernard | warm-hearted / woody | 3 | Winter Cabin |

6 reserved NPCs exist in the JSON but are not assigned any requests yet: Odette, Céline, Pascal, Dominic, Marcel, Claude.

---

## Persistence

All saves use `user://` path with JSON format.

| File | Managed by | Contents |
|------|-----------|----------|
| `save_data.json` | InventoryManager | Gathered ingredient counts |
| `cellar_data.json` | CellarManager | Play time, bottle inventory, aging rack, display shelf, extra rack slots |
| `processing_data.json` | ProcessingManager | Processing queue, ready oils, `has_met_processor` flag |
| `request_data.json` | RequestManager | Completed request IDs, current tier, blend counter, completion counts per tier |
| `accord_data.json` | AccordManager | Discovered accord resource paths |
| `coin_data.json` | CoinManager | Coin balance |

---

## Other Systems

### Skunk companion
- `SkunkManager` autoload keeps a single skunk instance alive across scene transitions
- On each scene load, the skunk is re-parented into the current scene and calls `spawn_near_player()`
- Skunk behavior script exists (`skunk.tscn`) but no gameplay mechanic is attached to it yet

### Scent radar graph
- `scent_radar_graph.gd` exists as a custom Control node
- Not currently placed in any scene or UI

### HUD
- Persistent CanvasLayer (layer 5) showing the current coin count
- Always visible, updates via `CoinManager.coins_changed` signal

---

## Known Gaps / Not Yet Done

- Raw ingredient icons exist only for cinnamon; other raws still use color dots
- Skunk has no gameplay effect yet
- Scent radar graph is unplaced
- Processor intro (`has_met_processor`) is saved but nothing reads it — no tutorial or intro dialogue tied to it
- 6 reserved NPCs have no requests assigned
- No end-of-content handling (all requests completed → `active_request = null`, board goes silent)
- Shop buy tab sells processed oils directly — bypasses the gather/process loop for players who want to skip gathering
