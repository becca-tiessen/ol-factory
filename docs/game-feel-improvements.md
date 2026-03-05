# Game Feel Improvements — Design Reference

## Context
The core mixing system (live feedback, quality formula, accords) is solid, but the loops around it don't create enough tension, surprise, or payoff. Four pain points: gathering is boring, nothing to do between mixes, discovery feels impossible, and no sense of progression.

These 5 changes are interconnected and ordered by priority. Each builds on the previous.

---

## Change 1: Accord Hints / Perfumer's Journal
**Priority: Highest — lowest effort, highest impact**

**Problem:** 7 accords require EXACT ingredient combos with NO extras. With zero guidance, blind discovery is essentially impossible.

**Solution:** Add poetic hints to each accord, show them in the mixing bench UI, and add "getting warmer" feedback during mixing.

**Changes:**
- **`scripts/base_accord.gd`** — Add `@export var hint: String = ""` field
- **`data/accords/*.tres`** — Add hint text to all 7 accords:
  - Twilight Woods (cedar+sandalwood): "Two woods, old and quiet, standing side by side."
  - Candy Cane (vanilla+peppermint): "A winter treat — sweetness wrapped in cool green."
  - Garden Path (rose+bergamot): "Sunlit petals along a citrus-scented path."
  - etc.
- **`scripts/accord_manager.gd`** — Add methods:
  - `get_hints() -> Array` — returns hint data for all accords (hint text for undiscovered, full recipe for discovered)
  - `get_progress_for_accord(accord, blend_counts) -> Dictionary` — returns which recipe ingredients are present/missing (enables "warm/cold" feedback)
  - Relax discovery: change `blend_counts.size() != recipe.size()` to allow 1 extra ingredient (`blend_counts.size() > recipe.size() + 1`)
- **`scripts/mixing_bench_ui.gd`** — Add collapsible "Journal" section showing:
  - All accords with hints (undiscovered) or recipes (discovered)
  - During active mixing: subtle warmth indicator per undiscovered accord ("Getting closer..." when partial match)

**Why first:** Makes the game's most exciting mechanic actually usable. Mostly data changes + one UI section.

---

## Change 2: Bonus Gathering
**Priority: High — tiny code change, immediate feel improvement**

**Problem:** Walk to bush, press E, get exactly 1 ingredient. Zero surprise, zero variety. Most frequent action in the game.

**Changes:**
- **`scripts/interactable.gd`** — Modify `collect()`:
  - Add `@export var bonus_chance: float = 0.25`
  - 25% chance of +1 bonus drop ("Bountiful Harvest! +2" popup)
  - 10% chance of "Pristine" gather (+1, special popup text)
  - Vary popup text and amount in existing `_show_collect_popup()`
  - Optional: brief tween color flash on bonus harvests

**Why:** The gathering popup system already exists — just vary the text and amount. Gathering goes from robotic to having micro-surprises.

**Connection:** Combined with Journal hints (Change 1), players gather with PURPOSE ("I need cedar and sandalwood for Twilight Woods") and ANTICIPATION ("maybe I'll get a bonus").

---

## Change 3: Reputation System
**Priority: High — provides the progression backbone**

**Problem:** After buying 2 rack slots (~50 coins), money is meaningless. Display shelf has zero impact. No visible sense of growing expertise.

**Changes:**
- **New file: `scripts/reputation_manager.gd`** — New autoload singleton:
  ```gdscript
  var reputation: int = 0
  signal reputation_changed(new_value: int)
  const MILESTONES = [
      { "rep": 5, "title": "Apprentice", "perk": "bonus_gather" },
      { "rep": 15, "title": "Journeyman", "perk": "extra_rack_slot" },
      { "rep": 30, "title": "Artisan", "perk": "accord_hint_upgrade" },
      { "rep": 50, "title": "Master Perfumer", "perk": "none" },
  ]
  func add_reputation(amount: int)
  func get_title() -> String
  func get_milestone_progress() -> Dictionary
  func has_perk(perk: String) -> bool
  ```
  - Saves to `user://reputation_data.json`
  - Sources: sell perfume (+1 to +4 by tier), complete request (+3 to +8 by tier), display bottle (+1 per unique tier)
- **`scripts/shop_ui.gd`** — On sell, call `ReputationManager.add_reputation()`
- **`scripts/request_manager.gd`** — On request complete, add reputation
- **`scripts/display_shelf_ui.gd`** — On display, add reputation (first display per tier only)
- **`scripts/hud.gd`** — Show current title + progress bar to next milestone
- **Perk integration:**
  - `bonus_gather`: In `interactable.gd`, increase bonus_chance from 25% → 40%
  - `extra_rack_slot`: In `cellar_manager.gd`, +1 rack slot
  - `accord_hint_upgrade`: In Journal, reveal one ingredient name instead of just family
- **Register as autoload in `project.godot`**

**Why:** Gives meaning to EVERY action. The title progression ("Apprentice" → "Master Perfumer") is the cozy artisan fantasy of growing expertise.

---

## Change 4: Blend Log
**Priority: Medium — pairs with Journal from Change 1**

**Problem:** No record of what you've tried. Makes systematic accord hunting impossible. Nothing to reflect on between mixes.

**Changes:**
- **New file: `scripts/blend_log_manager.gd`** — New autoload singleton:
  ```gdscript
  var entries: Array[Dictionary] = []
  signal log_updated
  func record_blend(blend: Array, breakdown: Dictionary, accords: Array[BaseAccord])
  func get_entries() -> Array[Dictionary]
  func get_best_quality() -> float
  func get_unique_combos_tried() -> int
  ```
  - Saves to `user://blend_log.json`, cap at 50 entries
- **`scripts/mixing_bench_ui.gd`** — In `_on_commit_pressed()`, call `BlendLogManager.record_blend()`
- **`scripts/mixing_bench_ui.gd`** — Add "Log" tab showing recent blends: recipe, quality, tier, gold star if accord discovered
- **Register as autoload in `project.godot`**

**Why:** Turns dead time between mixes into planning time. "I tried cedar+rose and got nothing — the hint says two woods, so maybe cedar+sandalwood?"

---

## Change 5: Cellar Tending
**Priority: Low — smallest impact, most isolated**

**Problem:** Aging is a pure time gate. Nothing to do while waiting 12 minutes.

**Changes:**
- **`scripts/cellar_manager.gd`** — Add tending state per rack entry:
  - `tend_count: int` (max 3), `last_tend_time: float`
  - Method `tend_bottle(rack_index) -> bool` — succeeds if 60+ seconds since last tend, adds +0.05 to `tend_bonus`
  - Include tend_bonus in age_bonus on retrieval
  - Save/load new fields
- **`scripts/cellar_ui.gd`** — Add "Tend" button per aging bottle:
  - Shows "Tend (X/3)" with count
  - Disabled if maxed or cooldown not elapsed
  - Cozy message on click ("You adjust the bottle's position on the rack...")

**Why:** Small, optional, cozy — you're caring for your creation. Can be deferred or skipped entirely.

---

## How They Connect

```
Journal Hints ──→ gives PURPOSE to gathering
     │                    │
     ▼                    ▼
Blend Log ──→ supports systematic discovery
     │
     ▼
Reputation ──→ gives MEANING to selling/gifting/displaying
     │              │
     ▼              ▼
Bonus Gather ◄── perk unlocks better gather chance

Cellar Tending ──→ fills the aging gap (optional)
```

## What Stays The Same
- Quality formula (works well)
- Request system structure (good scaffolding)
- Save system pattern (each manager gets own `user://` JSON)
- No new scenes or major UI overhauls
- No new ingredient resources required (though easier to add later with hint system)
