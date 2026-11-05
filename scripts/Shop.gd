extends VBoxContainer
## Shop: buy potions, runes and basic materials; sell spare weapons and materials.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/Pix.gd")

var town
var tab := "buy"
var tabs: HBoxContainer
var list: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	tabs = UI.hbox(4)
	add_child(tabs)
	list = UI.vbox(3)
	add_child(UI.scroll(list))
	_rebuild()

func _rebuild() -> void:
	UI.clear(tabs)
	for tb in [["buy", "Buy"], ["sell", "Sell"]]:
		var b = UI.btn(tb[1], func(): tab = tb[0]; _rebuild(), 70, 24)
		if tab == tb[0]:
			b.add_theme_color_override("font_color", UI.GOLD)
		tabs.add_child(b)
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(sp)
	tabs.add_child(UI.lbl("%d G" % Game.gold, 12, UI.GOLD))
	UI.clear(list)
	if tab == "buy":
		_section("Supplies")
		for id in Data.ITEM_ORDER:
			var it: Dictionary = Data.ITEMS[id]
			_row(Pix.item_icon(id), it.name, it.desc, int(Game.items.get(id, 0)), int(it.price), "Buy", func(): _buy("items", id, int(it.price)))
		_section("Runes (socket them at the Blacksmith)")
		for id in Data.RUNE_ORDER:
			var r: Dictionary = Data.RUNES[id]
			var col: Color = Data.ELEM_COLOR[r.elem] if r.elem != "" else UI.GOLD
			_row(Pix.gem(col, "rune"), r.name, r.desc, int(Game.runes.get(id, 0)), int(r.price), "Buy", func(): _buy("runes", id, int(r.price)))
		_section("Materials")
		for id in ["iron_ore", "beast_hide", "runestone"]:
			var m: Dictionary = Data.MATERIALS[id]
			var price = int(m.price) * 2
			_row(Pix.gem(m.color, "ore"), m.name, "Forging material.", int(Game.mats.get(id, 0)), price, "Buy", func(): _buy("mats", id, price))
	else:
		_section("Weapons (equipped weapons can't be sold)")
		var any = false
		for w in Game.weapons:
			if not Game.weapon_owner(w.uid).is_empty():
				continue
			any = true
			var val = Game.weapon_value(w)
			_row(Pix.weapon_icon(w.type, int(w.rarity), int(w.tier)), Game.weapon_label(w), " · ".join(Game.weapon_lines(w)), -1, val, "Sell", func():
				Game.remove_weapon(w.uid)
				Game.gold += val
				for r in w.runes:
					Game.add("runes", r, 1)
				Sfx.play("coin")
				_rebuild(), Data.RARITY_COLOR[int(w.rarity)])
		if not any:
			list.add_child(UI.lbl("No spare weapons.", 10, UI.DIM))
		_section("Materials (sell for half value)")
		for id in Data.MAT_ORDER:
			var n = int(Game.mats.get(id, 0))
			if n <= 0: continue
			var m: Dictionary = Data.MATERIALS[id]
			var price = int(m.price) / 2
			_row(Pix.gem(m.color, "ore"), m.name, "", n, price, "Sell", func():
				if int(Game.mats.get(id, 0)) <= 0: return
				Game.mats[id] = int(Game.mats[id]) - 1
				Game.gold += price
				Sfx.play("coin")
				_rebuild())
	town.refresh()

func _section(t: String) -> void:
	list.add_child(UI.lbl(t, 12, UI.GOLD))

func _row(tex: Texture2D, name: String, desc: String, owned: int, price: int, verb: String, cb: Callable, col := UI.INK) -> void:
	var p = UI.panel(4)
	list.add_child(p)
	var h = UI.hbox(6)
	p.add_child(h)
	h.add_child(UI.icon(tex, 22))
	var v = UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.lbl(name + ("   (own %d)" % owned if owned >= 0 else ""), 11, col))
	if desc != "":
		v.add_child(UI.wrap(desc, 9))
	var b = UI.btn("%s %dG" % [verb, price], cb, 84, 24)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if verb == "Buy":
		b.disabled = Game.gold < price
	h.add_child(b)

func _buy(dict_name: String, id: String, price: int) -> void:
	if Game.gold < price:
		Sfx.play("deny"); return
	Game.gold -= price
	Game.add(dict_name, id, 1)
	Sfx.play("coin")
	_rebuild()
