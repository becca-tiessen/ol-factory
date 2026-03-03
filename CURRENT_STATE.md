# ol-factory — Current Game State

## What You Can Do

### Explore
- **Outside scene**: Stone path area with greenery, trees, and a rose bush
- **Lab scene**: Contains the mixing bench
- **Cellar scene**: Accessible via doors
- Doors connect scenes via SceneManager (autoload)

### Gather Ingredients
- Walk up to the **rose bush** (outside scene, right side of path) and press **E**
- The bush shrinks away and "+1 Rose" floats above the player
- The rose is stored in InventoryManager (persists across scenes within a session)
- Only **one gatherable** exists so far (the rose bush). It doesn't respawn after collection.

### Mix Perfume
- Interact with the **mixing bench** (lab scene) to open the mixing UI
- **3-column layout**: ingredient list | blend drops + controls | results
- **Hybrid ingredient list**: all 7 ingredients from `res://data/` are shown. Gathered ones display a count (e.g. "Rose (1)"), ungathered ones appear dimmed but are still clickable
- Click an ingredient to add a drop to the blend
- **Calculate** button scores the blend (0-10) based on:
  - Pairwise scent family compatibility (e.g. woody+sweet = 0.9)
  - Balance modifier (penalizes one ingredient dominating)
  - Pyramid bonus (+0.5 for having top, middle, and base notes)
- Quality tiers: Poor (<3), Decent (<5.5), Good (<7.5), Excellent (>=7.5)
- **Clear** button resets the blend

## Ingredients Available (in `res://data/`)

| Ingredient  | Family  | Note     | Intensity | Gatherable? |
|-------------|---------|----------|-----------|-------------|
| Rose        | floral  | middle   | 6         | Yes (outside) |
| Jasmine     | floral  | middle   | 7         | No |
| Cedar       | woody   | base     | 5         | No |
| Sandalwood  | woody   | base     | 6         | No |
| Vanilla     | sweet   | base     | 7         | No |
| Bergamot    | citrus  | top      | 5         | No |
| Peppermint  | green   | top      | 8         | No |

## Key Systems

| System | Purpose | Script |
|--------|---------|--------|
| InventoryManager | Stores gathered ingredients (autoload) | `scripts/inventory_manager.gd` |
| Interactable | Gatherable resource nodes (Area2D, layer 2) | `scripts/interactable.gd` |
| PlayerInteraction | Detects nearby gatherables, triggers collect on E | `scripts/player_interaction.gd` |
| BaseInteractable | Furniture/UI interaction (StaticBody2D, layer 3) | `scripts/base_interactable.gd` |
| MixingManager | Blend logic, quality scoring | `scripts/mixing_manager.gd` |
| ScentCompatibility | Static compatibility table lookup | `scripts/scent_compatibility.gd` |
| SceneManager | Door/scene transitions (autoload) | `scripts/scene_manager.gd` |
| RequestManager | Tiered NPC request system (autoload) | `scripts/request_manager.gd` |

## NPC System
- **14 French-named NPCs** stored in `data/npcs.json` (8 active, 6 reserved for future use)
- Each NPC has: name, personality tag (romantic, picky, nostalgic, etc.), preferred scent family
- Each request in `data/requests.json` is attributed to an NPC via `npc_id`
- Request descriptions use the NPC's name and voice (e.g. "Charlotte is looking for...")
- Rejection messages reflect personality (picky NPCs are exacting, nostalgic ones are wistful, etc.)
- The bulletin board UI shows NPC name + personality tag beneath the request title

| NPC | Personality | Preferred Family | Requests |
|-----|-------------|-----------------|----------|
| Charlotte | romantic | floral | Flower Power, Heart Strings |
| Rémy | outdoorsy | green | A Fresh Start, Twilight Walk |
| Geneviève | nostalgic | woody | Woody Warmth, Deep Roots, The Legacy Blend |
| Noëlle | sweet-natured | sweet | Sweet Tooth, Sweet Symphony |
| Margot | picky | floral | Garden Party |
| Pierre | practical | citrus | Morning Lift |
| Simone | dramatic | sweet | Enchanted Evening |
| Bernard | warm-hearted | woody | Winter Cabin |

## Not Yet Implemented
- Gatherable bushes/trees for the other 6 ingredients
- Bush respawning after collection
- Inventory persistence across game sessions (save/load)
- Inventory UI outside the mixing bench
- Using up gathered ingredients when mixing (currently unlimited clicks)
