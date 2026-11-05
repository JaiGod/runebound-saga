extends Control
## Town of Emberhold: hub with Tavern, Blacksmith, Shop, Inn, Party and the Dungeon Gate.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/Pix.gd")
const SmithScript = preload("res://scripts/Smith.gd")
const ShopScript = preload("res://scripts/Shop.gd")
const PartyScript = preload("res://scripts/PartyMenu.gd")

var main
var params := {}
var t := 0.0
var hud: HBoxContainer
var hub: Control
var sub: Control
var sub_body: VBoxContainer
var sub_title: Label
var sub_back: Button
var founding := false
var lanterns: Array = []

func _ready() -> void:
	Sfx.music("town")
	founding = params.get("found", false)
	var r = RandomNumberGenerator.new()
	r.seed = 3
	for i in 10:
		lanterns.append(r.randf())
	var col = UI.vbox(6)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8; col.offset_right = -8; col.offset_top = 6; col.offset_bottom = -6
	add_child(col)
	hud = UI.hbox(6)
	col.add_child(hud)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	hub = CenterContainer.new()
	col.add_child(hub)
	_build_hub()
	_build_hud()
	# sub-panel frame
	sub = MarginContainer.new()
	sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		sub.add_theme_constant_override("margin_" + s, 6)
	sub.visible = false
	add_child(sub)
	var p = UI.panel(8)
	sub.add_child(p)
	var v = UI.vbox(6)
	p.add_child(v)
	var head = UI.hbox(6)
	v.add_child(head)
	sub_title = UI.lbl("", 16, UI.GOLD)
	sub_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sub_title)
	sub_back = UI.btn("< Back", close_sub, 70)
	head.add_child(sub_back)
	sub_body = UI.vbox(6)
	sub_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sub_body)
	resized.connect(_on_resized)
	if founding:
		open_tavern()
	else:
		Game.save_game()
	if params.has("msg"):
		main.toast(params.msg, UI.BAD)

func _on_resized() -> void:
	if hub and not sub.visible:
		_build_hub()

func portrait() -> bool:
	return size.y > size.x

func _build_hud() -> void:
	UI.clear(hud)
	var g = UI.lbl("%d G" % Game.gold, 13, UI.GOLD)
	hud.add_child(g)
	var fl = UI.lbl("  Floor %d/5" % Game.max_floor, 11, UI.DIM)
	hud.add_child(fl)
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(sp)
	for h in Game.party_heroes():
		var box = UI.vbox(0)
		box.add_child(UI.icon(Pix.hero(h.cls), 26))
		box.add_child(UI.lbl("Lv%d" % int(h.lvl), 9, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
		hud.add_child(box)
	var pb = UI.btn("II", func(): main.open_pause(), 30)
	hud.add_child(pb)

func _build_hub() -> void:
	UI.clear(hub)
	var p = UI.panel(10)
	hub.add_child(p)
	var v = UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.lbl("EMBERHOLD", 18, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl("the last town above the Runebound Depths", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var grid = GridContainer.new()
	grid.columns = 2 if portrait() else 3
	v.add_child(grid)
	var entries = [
		["Tavern", "Recruit & party", open_tavern],
		["Blacksmith", "Forge · upgrade · runes", open_smith],
		["Shop", "Potions & runes", open_shop],
		["Inn", "Rest & save", open_inn],
		["Party", "Stats & gear", open_party],
		["Dungeon Gate", "Descend", open_gate],
	]
	for e in entries:
		var b = UI.btn(e[0] + "\n" + e[1], e[2], 150, 44)
		b.add_theme_font_size_override("font_size", 12)
		grid.add_child(b)
	UI.focus_first(grid)

func refresh() -> void:
	_build_hud()

# ------------------------------------------------------------------ sub panels
func open_sub(title: String) -> VBoxContainer:
	UI.clear(sub_body)
	sub_title.text = title
	sub.visible = true
	hub.visible = false
	sub_back.visible = true
	return sub_body

func close_sub() -> void:
	if founding:
		if Game.roster.size() < 4:
			main.toast("Recruit four heroes to found your company.", UI.BAD)
			return
		founding = false
		Game.save_game()
		main.toast("The company is formed! Visit the Dungeon Gate when ready.")
	sub.visible = false
	hub.visible = true
	_build_hub()
	_build_hud()

func _unhandled_input(event: InputEvent) -> void:
	if sub.visible and event.is_action_pressed("pause"):
		close_sub()
		get_viewport().set_input_as_handled()

func open_tavern() -> void:
	var body = open_sub("Tavern — The Gilded Rune")
	if founding:
		body.add_child(UI.wrap("Choose FOUR heroes to found your company (%d/4). More can be hired later for gold." % Game.roster.size(), 11, UI.INK))
	else:
		body.add_child(UI.wrap("Hire more heroes and pick your active party of up to four (tap to toggle).", 11, UI.DIM))
	var list = UI.vbox(4)
	body.add_child(UI.scroll(list))
	for cls in Data.CLASS_ORDER:
		var c: Dictionary = Data.CLASSES[cls]
		var row = UI.panel(5)
		list.add_child(row)
		var h = UI.hbox(8)
		row.add_child(h)
		h.add_child(UI.icon(Pix.hero(cls), 40))
		var info = UI.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UI.wrap("%s  ·  %s  ·  %s" % [c.name, c.role, Data.ELEM_NAME[c.elem]], 12, Data.ELEM_COLOR[c.elem]))
		info.add_child(UI.wrap(c.desc, 10))
		var bs: Dictionary = c.base
		info.add_child(UI.wrap("HP %d  MP %d  ATK %d  MAG %d  DEF %d  SPD %d" % [bs.hp, bs.mp, bs.atk, bs.mag, bs.def, bs.spd], 9, UI.DIM))
		var b: Button
		if Game.has_class(cls):
			var hh: Dictionary = {}
			for x in Game.roster:
				if x.cls == cls: hh = x
			var active: bool = int(hh.id) in Game.party
			b = UI.btn("In Party" if active else "Bench", func(): _toggle_party(int(hh.id)), 90)
		elif founding:
			b = UI.btn("Recruit", func():
				Game.recruit(cls, true)
				Sfx.play("levelup")
				if Game.roster.size() >= 4:
					close_sub()
				else:
					open_tavern(), 90)
			b.disabled = Game.roster.size() >= 4
		else:
			var cost = Game.recruit_cost()
			b = UI.btn("Hire %dG" % cost, func():
				if Game.gold < cost:
					Sfx.play("deny"); main.toast("Not enough gold.", UI.BAD); return
				Game.gold -= cost
				var nh = Game.recruit(cls)
				main.toast("%s the %s joins! (Lv%d)" % [nh.name, c.name, nh.lvl])
				Sfx.play("levelup")
				open_tavern(); _build_hud(), 90)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	sub_back.visible = not founding or Game.roster.size() >= 4
	UI.focus_first(list)

func _toggle_party(id: int) -> void:
	if id in Game.party:
		if Game.party.size() <= 1:
			main.toast("You need at least one hero.", UI.BAD); return
		Game.party.erase(id)
	else:
		if Game.party.size() >= 4:
			main.toast("Party is full (4). Bench someone first.", UI.BAD); return
		Game.party.append(id)
	open_tavern(); _build_hud()

func open_inn() -> void:
	var body = open_sub("Inn — The Sleeping Lantern")
	var cost = 10 + 15 * (Game.max_floor - 1)
	body.add_child(UI.wrap("A warm bed and a hot stew. Resting restores all HP and MP and saves your journey.", 11, UI.INK))
	var b = UI.btn("Rest for the night (%dG)" % cost, func():
		if Game.gold < cost:
			Sfx.play("deny"); main.toast("Not enough gold.", UI.BAD); return
		Game.gold -= cost
		Game.heal_all()
		Game.save_game()
		Sfx.play("heal")
		main.toast("Rested and saved. Your party feels renewed!", UI.GOOD)
		_build_hud(), 220)
	body.add_child(b)
	body.add_child(UI.btn("Save game", func():
		if Game.save_game():
			main.toast("Game saved.", UI.GOOD)
		else:
			main.toast("Save failed.", UI.BAD), 220))
	var st: Dictionary = Game.stats
	body.add_child(UI.lbl("Chronicle", 13, UI.GOLD))
	body.add_child(UI.lbl("Battles won %d · Monsters slain %d · Chests %d · Weapons forged %d" % [st.wins, st.kills, st.chests, st.forged], 10, UI.DIM))
	body.add_child(UI.lbl("Bosses defeated %d/5 · Play time %s" % [Game.cleared.size(), Game.fmt_time(st.time)], 10, UI.DIM))
	for h in Game.party_heroes():
		var s = Game.hero_stats(h)
		body.add_child(UI.lbl("%s (%s Lv%d)  HP %d/%d  MP %d/%d" % [h.name, Data.CLASSES[h.cls].name, h.lvl, h.hp, s.hp, h.mp, s.mp], 10, UI.INK))
	UI.focus_first(body)

func open_gate() -> void:
	var body = open_sub("Dungeon Gate")
	body.add_child(UI.wrap("Floors unlock as you defeat each boss. HP/MP carry into the dungeon — rest at the inn first!", 11, UI.DIM))
	var list = UI.vbox(4)
	body.add_child(UI.scroll(list))
	for i in Data.FLOORS.size():
		var f: Dictionary = Data.FLOORS[i]
		var n = i + 1
		var unlocked = n <= Game.max_floor
		var done = n in Game.cleared
		var rec = [1, 4, 7, 11, 15][i]
		var label = "B%d  %s   (Lv %d+)%s" % [n, f.name, rec, "  [cleared]" if done else ""]
		if not unlocked:
			label = "B%d  ???  — defeat the boss of B%d" % [n, n - 1]
		var b = UI.btn(label, func(): _enter(n), 0, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not unlocked
		list.add_child(b)
	UI.focus_first(list)

func _enter(n: int) -> void:
	var alive = 0
	for h in Game.party_heroes():
		if int(h.hp) > 0: alive += 1
	if alive == 0:
		main.toast("Your party is exhausted. Rest at the Inn.", UI.BAD); return
	Sfx.play("stairs")
	main.goto("dungeon", {"floor": n})

func open_smith() -> void:
	var body = open_sub("Blacksmith — Hulda's Runeforge")
	var s = SmithScript.new()
	s.set("town", self)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(s)

func open_shop() -> void:
	var body = open_sub("Shop — Pell's Provisions")
	var s = ShopScript.new()
	s.set("town", self)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(s)

func open_party(focus_id := -1) -> void:
	var body = open_sub("Party")
	var s = PartyScript.new()
	s.set("town", self)
	s.set("sel", focus_id)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(s)

# ------------------------------------------------------------------ backdrop
func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var s = size
	for i in 10:
		draw_rect(Rect2(0, s.y * i / 10.0, s.x, s.y / 10.0 + 1), Color("2a1640").lerp(Color("c0583a"), float(i) / 12.0))
	draw_circle(Vector2(s.x * 0.15, s.y * 0.55), 40, Color("ffb36b", 0.5))
	var ground = s.y * 0.72
	var x = -10.0
	var i = 0
	while x < s.x:
		var w = 50.0 + 20.0 * sin(i * 2.1)
		var h = 60.0 + 30.0 * absf(sin(i * 1.3))
		var c = Color("1e1030").lerp(Color("2e1a3e"), 0.5 + 0.5 * sin(i))
		draw_rect(Rect2(x, ground - h, w, h + 4), c)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, ground - h), Vector2(x + w * 0.5, ground - h - 22), Vector2(x + w + 4, ground - h)]), Color("140a22"))
		for wy in range(int(ground - h + 10), int(ground - 8), 18):
			var lit = sin(i * 3.0 + wy) > -0.2
			draw_rect(Rect2(x + 8, wy, 7, 8), Color(1, 0.78, 0.4, 0.85) if lit else Color("0e0818"))
			draw_rect(Rect2(x + w - 15, wy, 7, 8), Color(1, 0.7, 0.35, 0.7) if not lit else Color("0e0818"))
		x += w + 8
		i += 1
	draw_rect(Rect2(0, ground, s.x, s.y - ground), Color("170c22"))
	for j in lanterns.size():
		var lx: float = lanterns[j] * s.x
		var fl = 0.7 + 0.3 * sin(t * 6.0 + j)
		draw_line(Vector2(lx, ground), Vector2(lx, ground - 26), Color("0a0612"), 2)
		draw_circle(Vector2(lx, ground - 28), 3, Color(1, 0.8, 0.4, fl))
		draw_circle(Vector2(lx, ground - 28), 9, Color(1, 0.7, 0.3, 0.15 * fl))
