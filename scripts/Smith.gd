extends VBoxContainer
## Blacksmith: forge new weapons from materials, upgrade +1..+5, socket runes, salvage.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/Pix.gd")

var town
var tab := "forge"
var forge_type := "sword"
var sel_uid := -1
var body: VBoxContainer
var tabs: HBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	tabs = UI.hbox(4)
	add_child(tabs)
	body = UI.vbox(6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	# default forge type = first party hero's weapon
	var ph: Array = Game.party_heroes()
	if ph.size() > 0:
		forge_type = Data.CLASSES[ph[0].cls].weapon
	_rebuild()

func _rebuild() -> void:
	UI.clear(tabs)
	for tb in [["forge", "Forge"], ["weapons", "Upgrade & Runes"]]:
		var b = UI.btn(tb[1], func(): tab = tb[0]; _rebuild(), 0, 24)
		if tab == tb[0]:
			b.add_theme_color_override("font_color", UI.GOLD)
		tabs.add_child(b)
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(sp)
	tabs.add_child(UI.lbl("%d G" % Game.gold, 12, UI.GOLD))
	UI.clear(body)
	body.add_child(_mats_row())
	if tab == "forge":
		_build_forge()
	else:
		_build_weapons()
	town.refresh()

func _mats_row() -> Control:
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	for m in Data.MAT_ORDER:
		var n = int(Game.mats.get(m, 0))
		var h = UI.hbox(2)
		h.add_child(UI.icon(Pix.gem(Data.MATERIALS[m].color, "ore"), 14))
		h.add_child(UI.lbl("%s %d" % [Data.MATERIALS[m].name, n], 10, UI.INK if n > 0 else UI.DIM))
		flow.add_child(h)
	return flow

func _cost_text(cost: Dictionary) -> String:
	var parts = ["%dG" % int(cost.gold)]
	for m in cost.mats:
		if int(cost.mats[m]) > 0:
			parts.append("%s x%d (%d)" % [Data.MATERIALS[m].name, int(cost.mats[m]), int(Game.mats.get(m, 0))])
	return ", ".join(parts)

func _build_forge() -> void:
	var types = HFlowContainer.new()
	types.add_theme_constant_override("h_separation", 4)
	types.add_theme_constant_override("v_separation", 4)
	body.add_child(types)
	for ty in Data.WEAPON_TYPES:
		var users = []
		for c in Data.CLASS_ORDER:
			if Data.CLASSES[c].weapon == ty: users.append(Data.CLASSES[c].name)
		var b = UI.btn(Data.WEAPON_TYPES[ty].name, func(): forge_type = ty; _rebuild(), 92, 26)
		b.icon = Pix.weapon_icon(ty, 2, 1)
		b.tooltip_text = "Used by " + ", ".join(users)
		if ty == forge_type:
			b.add_theme_color_override("font_color", UI.GOLD)
			b.add_theme_stylebox_override("normal", UI.sb(Color("4a3a78"), UI.GOLD))
		types.add_child(b)
	var users2 = []
	for c in Data.CLASS_ORDER:
		if Data.CLASSES[c].weapon == forge_type: users2.append(Data.CLASSES[c].name)
	body.add_child(UI.wrap("%s — wielded by %s. Weapon tier: %s" % [Data.WEAPON_TYPES[forge_type].name, ", ".join(users2), Data.TIER_NAMES[Game.forge_tier(0)]], 10, UI.DIM))
	var list = UI.vbox(4)
	body.add_child(UI.scroll(list))
	for r in Data.RECIPES:
		var cost = Game.recipe_cost(r)
		var row = UI.panel(5)
		list.add_child(row)
		var h = UI.hbox(6)
		row.add_child(h)
		var info = UI.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var odds = ["mostly Common/Uncommon", "good odds of Rare+", "high odds of Epic/Legendary, +1 tier"][r.q]
		info.add_child(UI.wrap(r.name + "  (" + odds + ")", 12, UI.INK))
		info.add_child(UI.wrap(_cost_text(cost), 10, UI.GOOD if Game.can_pay(cost) else UI.DIM))
		var b = UI.btn("Forge!", func(): _forge(r), 70)
		b.disabled = not Game.can_pay(cost)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	UI.focus_first(list)

func _forge(r: Dictionary) -> void:
	var cost = Game.recipe_cost(r)
	if not Game.can_pay(cost):
		Sfx.play("deny"); return
	Game.pay(cost)
	var tier = Game.forge_tier(r.q)
	var w = Game.make_weapon(forge_type, tier, Game.roll_rarity(r.q, tier))
	Game.weapons.append(w)
	Game.stats.forged += 1
	Sfx.play("forge")
	town.main.shake(4.0)
	_reveal(w)

func _reveal(w: Dictionary) -> void:
	_rebuild()
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	town.add_child(dim)
	var c = CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(c)
	var p = UI.panel(12)
	p.add_theme_stylebox_override("panel", UI.sb(Color("1e1630"), Data.RARITY_COLOR[int(w.rarity)], 3, 4, 12))
	c.add_child(p)
	var v = UI.vbox(4)
	v.custom_minimum_size.x = 250
	p.add_child(v)
	v.add_child(UI.lbl("FORGED!", 12, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var ic = UI.icon(Pix.weapon_icon(w.type, int(w.rarity), int(w.tier)), 64)
	v.add_child(ic)
	v.add_child(UI.lbl(Game.weapon_label(w), 15, Data.RARITY_COLOR[int(w.rarity)], HORIZONTAL_ALIGNMENT_CENTER))
	for line in Game.weapon_lines(w):
		v.add_child(UI.lbl(line, 10, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if int(w.rarity) >= 3:
		Sfx.play("levelup")
	p.pivot_offset = Vector2(125, 80)
	p.scale = Vector2(0.4, 0.4)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var b = UI.btn("Nice!", dim.queue_free)
	v.add_child(b)
	b.grab_focus()

# ------------------------------------------------------------------ weapons tab
func _build_weapons() -> void:
	var split = BoxContainer.new()
	split.vertical = town.portrait()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 6)
	body.add_child(split)
	var list = UI.vbox(3)
	var sc = UI.scroll(list)
	sc.custom_minimum_size = Vector2(230, 110)
	split.add_child(sc)
	if Game.weapon(sel_uid).is_empty() and Game.weapons.size() > 0:
		sel_uid = int(Game.weapons[0].uid)
	for w in Game.weapons:
		var owner = Game.weapon_owner(w.uid)
		var b = UI.btn(Game.weapon_label(w) + ("  [" + owner.name + "]" if not owner.is_empty() else ""), func(): sel_uid = int(w.uid); _rebuild(), 0, 24)
		b.icon = Pix.weapon_icon(w.type, int(w.rarity), int(w.tier))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Data.RARITY_COLOR[int(w.rarity)])
		b.add_theme_font_size_override("font_size", 10)
		if int(w.uid) == sel_uid:
			b.add_theme_stylebox_override("normal", UI.sb(Color("4a3a78"), UI.GOLD))
		list.add_child(b)
	var det = UI.vbox(4)
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(UI.scroll(det))
	var w = Game.weapon(sel_uid)
	if w.is_empty():
		det.add_child(UI.lbl("No weapons yet.", 11, UI.DIM))
		return
	det.add_child(UI.lbl(Game.weapon_label(w), 13, Data.RARITY_COLOR[int(w.rarity)]))
	for line in Game.weapon_lines(w):
		det.add_child(UI.wrap(line, 10, UI.INK))
	# upgrade
	if int(w.plus) < 5:
		var cost = Game.upgrade_cost(w)
		var ub = UI.btn("Upgrade to +%d" % (int(w.plus) + 1), func():
			if not Game.can_pay(cost):
				Sfx.play("deny"); return
			Game.pay(cost)
			w.plus = int(w.plus) + 1
			Sfx.play("forge")
			town.main.shake(3.0)
			town.main.toast("%s is now +%d!" % [w.name, w.plus], UI.GOOD)
			_rebuild())
		ub.disabled = not Game.can_pay(cost)
		det.add_child(ub)
		det.add_child(UI.wrap("Cost: " + _cost_text(cost), 9, UI.DIM))
	else:
		det.add_child(UI.lbl("Fully upgraded (+5).", 10, UI.GOLD))
	# runes
	var free = int(w.sockets) - w.runes.size()
	if int(w.sockets) > 0:
		det.add_child(UI.wrap("Socket a rune (30G) — %d free" % free, 11, UI.GOLD))
		var flow = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		det.add_child(flow)
		var any = false
		for r in Data.RUNE_ORDER:
			var n = int(Game.runes.get(r, 0))
			if n <= 0: continue
			any = true
			var rb = UI.btn("%s x%d" % [Data.RUNES[r].name, n], func():
				if Game.gold < 30:
					Sfx.play("deny"); return
				Game.gold -= 30
				Game.runes[r] = int(Game.runes[r]) - 1
				w.runes.append(r)
				Sfx.play("magic")
				town.main.toast("%s socketed!" % Data.RUNES[r].name, UI.GOOD)
				_rebuild(), 0, 22)
			rb.icon = Pix.gem(Data.ELEM_COLOR.get(Data.RUNES[r].elem, Color("ffd36b")) if Data.RUNES[r].elem != "" else Color("ffd36b"), "rune")
			rb.tooltip_text = Data.RUNES[r].desc
			rb.add_theme_font_size_override("font_size", 10)
			rb.disabled = free <= 0 or Game.gold < 30
			flow.add_child(rb)
		if not any:
			det.add_child(UI.wrap("You own no runes. Buy them at the shop or find them in chests.", 9, UI.DIM))
		if w.runes.size() > 0:
			det.add_child(UI.btn("Clear sockets (runes are destroyed)", func():
				w.runes.clear(); Sfx.play("debuff"); _rebuild(), 0, 22))
	# salvage
	var owner = Game.weapon_owner(w.uid)
	if owner.is_empty():
		var sb = UI.btn("Salvage for materials", func(): _salvage(w), 0, 22)
		det.add_child(sb)
	else:
		det.add_child(UI.lbl("Equipped by %s." % owner.name, 10, UI.DIM))

func _salvage(w: Dictionary) -> void:
	var got = {"iron_ore": 1 + int(w.tier), "runestone": int(w.rarity) / 2 + (1 if int(w.plus) >= 3 else 0)}
	if int(w.rarity) >= 4: got["starsteel"] = 1
	var parts = []
	for m in got:
		if got[m] > 0:
			Game.add("mats", m, got[m])
			parts.append("%s x%d" % [Data.MATERIALS[m].name, got[m]])
	for r in w.runes:
		Game.add("runes", r, 1)
	Game.remove_weapon(w.uid)
	sel_uid = -1
	Sfx.play("coin")
	town.main.toast("Salvaged: " + ", ".join(parts), UI.GOOD)
	_rebuild()
