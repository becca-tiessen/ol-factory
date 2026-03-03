# Two Interaction Systems: When to Use Each

You now have TWO different interaction systems. They handle different things and can coexist in the same game!

## System 1: BaseInteractable (for Furniture/UI)
**Uses:** StaticBody2D with an InteractionArea
**Purpose:** Open UIs (cellar, mixing bench, table)
**How it works:** Detects player body, opens a UI scene on E key

**Files:**
- `scripts/base_interactable.gd` - Base class
- `scripts/cellar.gd`, `scripts/mixing_bench.gd` - Subclasses
- UI scenes: `cellar_ui.tscn`, `mixing_bench_ui.tscn`

**Example:** Cellar → Player presses E → Cellar UI opens with inventory

---

## System 2: Interactable (for Gathering Resources)
**Uses:** Area2D with collision_layer=2
**Purpose:** Collect ingredients (roses, berries, etc.)
**How it works:** Detects player's InteractionArea, collects on E key, emits signal

**Files:**
- `scripts/interactable.gd` - Base class
- `scenes/rose_bush.tscn` - Example resource

**Example:** Rose bush → Player presses E → Bounce animation → Rose added to inventory

---

## How They Work Together

### Collision Setup
- **Layer 1**: Player body (collision with walls/furniture)
- **Layer 2**: Gatherable resources (roses, berries)
- **Layer 3**: Furniture (cellar, table) with UI

### Player Script Components
1. **PlayerInteraction** (Node)
   - Listens for E key
   - Detects **Area2D** interactables (layer 2)
   - Calls `collect()` on resources

2. **base_interactable's input handling**
   - Listens for E key
   - Detects player **body** via InteractionArea
   - Opens UI on furniture

### Why No Conflict?
- Resources use **Area2D-to-Area2D** collision (InteractionArea detects them)
- Furniture use **Area2D-to-Body** collision (InteractionArea detects player body entering an InteractionArea)
- Both listen to E key, but only the closest one acts (resources) or only if in range (furniture)

---

## How to Use Each

### Setting Up a Gatherable Resource (Rose)
1. Create Area2D scene with sprite + collision
2. Attach `Interactable` script
3. Drag your BaseIngredient resource into the `ingredient` export var
4. Set `collision_layer = 2`, `collision_mask = 0`
5. Done! Player can collect it

### Setting Up Furniture (Cellar, Table)
1. Create StaticBody2D scene with sprite + collision
2. Attach BaseInteractable subclass (e.g., `cellar.gd`)
3. Set `collision_layer = 3`, `collision_mask = 1`
4. Done! Player can interact to open UI

---

## Connecting to Your Inventory

### For Gathered Resources:
```gdscript
func _ready():
    var rose_bush = get_tree().current_scene.find_child("RoseBush")
    if rose_bush:
        rose_bush.ingredient_gathered.connect(_on_ingredient_gathered)

func _on_ingredient_gathered(ingredient: BaseIngredient):
    inventory.add(ingredient)
```

### For Furniture/Mixing:
Already handled by MixingManager! When you click an ingredient in mixing bench, it's added to the manager, which calculates the color.

---

## Quick Reference

| System | Root Node | Purpose | Signal | Uses E Key? |
|--------|-----------|---------|--------|------------|
| BaseInteractable | StaticBody2D | Open UIs | `opened` | Yes |
| Interactable | Area2D | Gather items | `ingredient_gathered` | Yes |

Both can be in the same scene without conflict!
