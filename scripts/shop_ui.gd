extends BaseInteractableUI

## Shop UI with Sell and Buy tabs.
## Sell: list finished perfumes with sale prices.
## Buy: ingredient bundles and extra aging rack slots.

const TIER_PRICES := {
	"Poor": 5,
	"Decent": 15,
	"Good": 35,
	"Excellent": 75,
}
const COINS_PER_AGE_TICK := 2

const BUNDLE_SIZE := 3
const RACK_SLOT_PRICE := 25

## Ingredient price by intensity bracket.
const INGREDIENT_PRICES := {
	"low": 10,   # intensity <= 5
	"mid": 12,   # intensity 6-7
	"high": 15,  # intensity >= 8
}

enum Tab { SELL, BUY }
var _current_tab: Tab = Tab.SELL

var _all_ingredients: Array[BaseIngredient] = []


func _ready() -> void:
	super()
	_scan_ingredients()
	%SellTab.pressed.connect(func(): _switch_tab(Tab.SELL))
	%BuyTab.pressed.connect(func(): _switch_tab(Tab.BUY))
	CellarManager.bottles_changed.connect(_refresh)
	CoinManager.coins_changed.connect(_refresh)
	CellarManager.rack_changed.connect(_refresh)
	InventoryManager.inventory_changed.connect(_refresh)


func open() -> void:
	_refresh()
	super()


func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	_refresh()


func _refresh() -> void:
	_update_coin_label()
	_update_tab_buttons()
	for child in %ItemList.get_children():
		child.queue_free()

	if _current_tab == Tab.SELL:
		_build_sell_tab()
	else:
		_build_buy_tab()


func _update_coin_label() -> void:
	%CoinLabel.text = "Coins: %d" % CoinManager.get_coins()
	%CoinLabel.add_theme_color_override("font_color", UITheme.GOLD)


func _update_tab_buttons() -> void:
	%SellTab.disabled = _current_tab == Tab.SELL
	%BuyTab.disabled = _current_tab == Tab.BUY


# ---------------------------------------------------------------------------
# Sell tab
# ---------------------------------------------------------------------------

func _build_sell_tab() -> void:
	if CellarManager.bottles.is_empty():
		var lbl := Label.new()
		lbl.text = "You have no perfumes to sell."
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%ItemList.add_child(lbl)
		return

	for bottle in CellarManager.bottles:
		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		card.add_child(hbox)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = bottle.get_label()
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(name_lbl)

		var quality_lbl := Label.new()
		var tier := bottle.get_final_tier()
		quality_lbl.text = "%s — Quality: %.1f" % [tier, bottle.get_final_quality()]
		quality_lbl.add_theme_color_override("font_color", UITheme.SOFT_BLUE)
		info.add_child(quality_lbl)

		if bottle.aged:
			var aged_lbl := Label.new()
			aged_lbl.text = "(aged +%.2f)" % bottle.age_bonus
			aged_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
			info.add_child(aged_lbl)

		hbox.add_child(info)

		var price := _calculate_price(bottle)
		var price_lbl := Label.new()
		price_lbl.text = "%d coins" % price
		price_lbl.add_theme_color_override("font_color", UITheme.GOLD)
		price_lbl.add_theme_font_size_override("font_size", 16)
		price_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(price_lbl)

		var sell_btn := Button.new()
		sell_btn.text = "Sell"
		sell_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var b := bottle
		var p := price
		sell_btn.pressed.connect(func(): _on_sell(b, p))
		hbox.add_child(sell_btn)

		%ItemList.add_child(card)


func _calculate_price(bottle: BottledPerfume) -> int:
	var tier := bottle.get_final_tier()
	var base_price: int = TIER_PRICES.get(tier, 5)
	var age_ticks := int(bottle.age_bonus / 0.25)
	return base_price + age_ticks * COINS_PER_AGE_TICK


func _on_sell(bottle: BottledPerfume, price: int) -> void:
	CellarManager.remove_bottle(bottle)
	CoinManager.add_coins(price)


# ---------------------------------------------------------------------------
# Buy tab
# ---------------------------------------------------------------------------

func _scan_ingredients() -> void:
	var dir := DirAccess.open("res://data")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load("res://data/" + file_name)
		if res is BaseIngredient:
			_all_ingredients.append(res)
	_all_ingredients.sort_custom(func(a, b): return a.display_name < b.display_name)


func _get_ingredient_price(ingredient: BaseIngredient) -> int:
	if ingredient.intensity >= 8:
		return INGREDIENT_PRICES["high"]
	elif ingredient.intensity >= 6:
		return INGREDIENT_PRICES["mid"]
	else:
		return INGREDIENT_PRICES["low"]


func _build_buy_tab() -> void:
	# Ingredient bundles
	for ingredient in _all_ingredients:
		var price := _get_ingredient_price(ingredient)
		var can_afford := CoinManager.get_coins() >= price

		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		# Scent-family pip
		var pip := Label.new()
		pip.text = "\u25cf"
		pip.add_theme_color_override("font_color", UITheme.get_family_color(ingredient.scent_family))
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(pip)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = "%s x%d" % [ingredient.display_name, BUNDLE_SIZE]
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = "%s / %s note" % [ingredient.scent_family, ingredient.note_position]
		desc_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		info.add_child(desc_lbl)

		hbox.add_child(info)

		var price_lbl := Label.new()
		price_lbl.text = "%d coins" % price
		price_lbl.add_theme_color_override("font_color", UITheme.GOLD if can_afford else UITheme.TEXT_MUTED)
		price_lbl.add_theme_font_size_override("font_size", 16)
		price_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(price_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.disabled = not can_afford
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ing := ingredient
		var p := price
		buy_btn.pressed.connect(func(): _on_buy_ingredient(ing, p))
		hbox.add_child(buy_btn)

		%ItemList.add_child(card)

	# Separator before rack slots
	var sep := HSeparator.new()
	%ItemList.add_child(sep)

	# Extra aging rack slots
	var slots_owned := CellarManager.extra_rack_slots
	var max_extra := CellarManager.MAX_EXTRA_RACK_SLOTS
	var can_buy_slot := CellarManager.can_buy_rack_slot()
	var can_afford_slot := CoinManager.get_coins() >= RACK_SLOT_PRICE

	var card := PanelContainer.new()
	var hbox := HBoxContainer.new()
	card.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = "Extra Aging Rack Slot"
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	if can_buy_slot:
		desc_lbl.text = "Owned: %d / %d" % [slots_owned, max_extra]
	else:
		desc_lbl.text = "Fully upgraded (%d / %d)" % [slots_owned, max_extra]
	desc_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	info.add_child(desc_lbl)

	hbox.add_child(info)

	var price_lbl := Label.new()
	price_lbl.text = "%d coins" % RACK_SLOT_PRICE
	var buyable := can_buy_slot and can_afford_slot
	price_lbl.add_theme_color_override("font_color", UITheme.GOLD if buyable else UITheme.TEXT_MUTED)
	price_lbl.add_theme_font_size_override("font_size", 16)
	price_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.disabled = not buyable
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_btn.pressed.connect(_on_buy_rack_slot)
	hbox.add_child(buy_btn)

	%ItemList.add_child(card)


func _on_buy_ingredient(ingredient: BaseIngredient, price: int) -> void:
	if not CoinManager.spend_coins(price):
		return
	InventoryManager.add_ingredient(ingredient, BUNDLE_SIZE)


func _on_buy_rack_slot() -> void:
	if not CoinManager.spend_coins(RACK_SLOT_PRICE):
		return
	CellarManager.buy_rack_slot()
