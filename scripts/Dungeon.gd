extends Control
## Grid dungeon exploration: procedural rooms, fog of war, chests, traps, roaming monsters, boss and stairs.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/Pix.gd")
const W := 33
const H := 25
const TS := 32.0
const DIRS := {"mv_up": Vector2i(0, -1), "mv_down": Vector2i(0, 1), "mv_left": Vector2i(-1, 0), "mv_right": Vector2i(1, 0)}

var main
var params := {}
var floor_n := 1
var fi := 0
var grid := PackedByteArray()   # 0 wall, 1 floor
var seen := PackedByteArray()
var deco := PackedByteArray()
var objs := {}                  # Vector2i -> {type, ...}
var foes: Array = []            # {pos, ids, boss, stun, alive}
var player := Vector2i.ZERO
var draw_pos := Vector2.ZERO
var path: Array = []
var hold_dir := Vector2i.ZERO
var move_cd := 0.0
var t := 0.0
var busy := false
var rng := RandomNumberGenerator.new()
var hud_top: HBoxContainer
var party_box: HBoxContainer
var bag: Control
var fx: Array = []              # floating texts {text,pos,t,col}
var parts: Array = []
var boss_dead := false
var _engaged = null

func _ready() -> void:
	floor_n = int(params.get("floor", 1))
	fi = floor_n - 1
	Sfx.music("dungeon")
	rng.randomize()
	_generate()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_hud()
	_reveal()
	draw_pos = Vector2(player)
	main.toast("B%d — %s" % [floor_n, Data.FLOORS[fi].name])

# ------------------------------------------------------------------ generation
func idx(p: Vector2i) -> int:
	return p.y * W + p.x

func walkable(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H and grid[idx(p)] == 1

func _generate() -> void:
	grid.resize(W * H); grid.fill(0)
	seen.resize(W * H); seen.fill(0)
	deco.resize(W * H)
	for i in deco.size():
		deco[i] = 2 if rng.randf() < 0.08 else (1 if rng.randf() < 0.15 else 0)
	var rooms: Array = []
	var tries = 0
	while rooms.size() < 9 and tries < 400:
		tries += 1
		var rw = rng.randi_range(4, 7); var rh := rng.randi_range(3, 6)
		var r = Rect2i(rng.randi_range(1, W - rw - 2), rng.randi_range(1, H - rh - 2), rw, rh)
		var ok = true
		for o in rooms:
			if r.grow(1).intersects(o):
				ok = false; break
		if ok:
			rooms.append(r)
	rooms.sort_custom(func(a, b): return a.position.x + a.position.y * 0.5 < b.position.x + b.position.y * 0.5)
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				grid[y * W + x] = 1
	for i in range(1, rooms.size()):
		_corridor(_center(rooms[i - 1]), _center(rooms[i]))
	for i in 2:  # a couple of loops
		_corridor(_center(rooms[rng.randi() % rooms.size()]), _center(rooms[rng.randi() % rooms.size()]))
	player = _center(rooms[0])
	objs[player] = {"type": "portal"}
	# farthest room = boss
	var dist = _bfs(player)
	var far = 1
	for i in rooms.size():
		if dist.get(_center(rooms[i]), 0) > dist.get(_center(rooms[far]), 0):
			far = i
	var boss_pos = _center(rooms[far])
	var cleared: bool = floor_n in Game.cleared
	foes.append({"pos": boss_pos, "ids": _boss_group(), "boss": true, "stun": 0, "alive": true})
	# chests, fountain, foes in other rooms
	var free_tiles: Array = []
	for i in rooms.size():
		if i == 0 or i == far: continue
		for y in range(rooms[i].position.y, rooms[i].end.y):
			for x in range(rooms[i].position.x, rooms[i].end.x):
				free_tiles.append(Vector2i(x, y))
	free_tiles.shuffle()
	var n_chest = 6
	for i in n_chest:
		var p: Vector2i = free_tiles.pop_back()
		objs[p] = {"type": "chest", "open": false}
	var fp: Vector2i = free_tiles.pop_back()
	objs[fp] = {"type": "fountain", "used": false}
	for i in 10:
		if free_tiles.is_empty(): break
		var p: Vector2i = free_tiles.pop_back()
		foes.append({"pos": p, "ids": _group(), "boss": false, "stun": 0, "alive": true})
	# traps in corridors
	var corridor: Array = []
	for y in H:
		for x in W:
			var p = Vector2i(x, y)
			if walkable(p) and not _in_rooms(p, rooms) and not objs.has(p):
				corridor.append(p)
	corridor.shuffle()
	for i in mini(7, corridor.size()):
		objs[corridor[i]] = {"type": "trap", "kind": ["spikes", "gas", "alarm", "spikes", "rune"][rng.randi() % 5], "found": false}
	if cleared:
		main_toast_later = "This floor's boss returns, stronger than ever..."

var main_toast_later := ""

func _in_rooms(p: Vector2i, rooms: Array) -> bool:
	for r in rooms:
		if r.has_point(p): return true
	return false

func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2

func _corridor(a: Vector2i, b: Vector2i) -> void:
	var p = a
	var horiz_first = rng.randf() < 0.5
	while p != b:
		if (horiz_first and p.x != b.x) or p.y == b.y:
			p.x += signi(b.x - p.x)
		else:
			p.y += signi(b.y - p.y)
		grid[idx(p)] = 1

func _bfs(from: Vector2i, avoid_found_traps := false) -> Dictionary:
	var d = {from: 0}
	var q = [from]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		for k in DIRS:
			var n: Vector2i = c + DIRS[k]
			if walkable(n) and not d.has(n):
				if avoid_found_traps and objs.has(n) and objs[n].type == "trap" and objs[n].found:
					continue
				d[n] = d[c] + 1
				q.append(n)
	return d

func _group() -> Array:
	var pool: Array = Data.FLOORS[fi].enemies
	var n = rng.randi_range(1, 3) if floor_n > 1 else rng.randi_range(1, 2)
	var g = []
	for i in n:
		g.append(pool[rng.randi() % pool.size()])
	return g

func _boss_group() -> Array:
	var g = [Data.FLOORS[fi].boss]
	if floor_n >= 3:
		g.append(Data.FLOORS[fi].enemies[rng.randi() % 3])
	return g

# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	var top = UI.hbox(6)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 6; top.offset_right = -6; top.offset_top = 4
	add_child(top)
	hud_top = top
	party_box = UI.hbox(4)
	party_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	party_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	party_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	party_box.offset_right = -6; party_box.offset_bottom = -6
	add_child(party_box)
	# D-pad
	var pad = GridContainer.new()
	pad.columns = 3
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pad.offset_left = 6; pad.offset_bottom = -6
	add_child(pad)
	for cell in [["", ""], ["^", "mv_up"], ["", ""], ["<", "mv_left"], ["o", "act"], [">", "mv_right"], ["", ""], ["v", "mv_down"], ["", ""]]:
		if cell[1] == "":
			var e = Control.new(); e.custom_minimum_size = Vector2(34, 34); e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pad.add_child(e); continue
		var b = Button.new()
		b.text = cell[0]
		b.custom_minimum_size = Vector2(34, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.modulate.a = 0.75
		if cell[1] == "act":
			b.pressed.connect(func(): _open_bag())
			b.text = "Bag"
			b.add_theme_font_size_override("font_size", 9)
		else:
			var d: Vector2i = DIRS[cell[1]]
			b.button_down.connect(func(): hold_dir = d; path.clear(); move_cd = 0.0)
			b.button_up.connect(func():
				if hold_dir == d:
					hold_dir = Vector2i.ZERO)
		pad.add_child(b)
	_refresh_hud()

func _refresh_hud() -> void:
	UI.clear(hud_top)
	hud_top.add_child(UI.lbl("B%d %s" % [floor_n, Data.FLOORS[fi].name], 12, Color(Data.FLOORS[fi].pal.accent)))
	hud_top.add_child(UI.lbl("  %d G" % Game.gold, 12, UI.GOLD))
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_top.add_child(sp)
	var bagb = UI.btn("Bag", _open_bag, 44, 24)
	bagb.focus_mode = Control.FOCUS_NONE
	hud_top.add_child(bagb)
	var pb = UI.btn("II", func(): main.open_pause(), 30, 24)
	pb.focus_mode = Control.FOCUS_NONE
	hud_top.add_child(pb)
	UI.clear(party_box)
	for h in Game.party_heroes():
		var s = Game.hero_stats(h)
		var card = HeroMini.new()
		card.h = h; card.s = s
		party_box.add_child(card)

class HeroMini extends Control:
	const Pix2 = preload("res://scripts/Pix.gd")
	var h: Dictionary
	var s: Dictionary
	func _init() -> void:
		custom_minimum_size = Vector2(54, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.05, 0.12, 0.85))
		draw_rect(Rect2(Vector2.ZERO, size), Color("5a4890"), false, 1.0)
		draw_texture_rect(Pix2.hero(h.cls), Rect2(1, 1, 20, 20), false, Color(1, 1, 1, 1) if int(h.hp) > 0 else Color(0.4, 0.4, 0.4, 0.8))
		draw_string(ThemeDB.fallback_font, Vector2(23, 12), "Lv%d" % int(h.lvl), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("f2ead8"))
		var hf = float(h.hp) / maxf(1, s.hp)
		draw_rect(Rect2(3, 24, 48, 4), Color("0c0814"))
		draw_rect(Rect2(3, 24, 48 * hf, 4), Color("7be06a") if hf > 0.35 else Color("ff6a6a"))
		draw_rect(Rect2(3, 30, 48, 3), Color("0c0814"))
		draw_rect(Rect2(3, 30, 48 * float(h.mp) / maxf(1, s.mp), 3), Color("5fb4ff"))

# ------------------------------------------------------------------ input & movement
func _unhandled_input(event: InputEvent) -> void:
	if busy or bag:
		if bag and event.is_action_pressed("pause"):
			_close_bag(); get_viewport().set_input_as_handled()
		return
	for a in DIRS:
		if event.is_action_pressed(a):
			path.clear()
			_try_step(DIRS[a])
			move_cd = 0.22
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if busy or bag:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var off = _cam_offset()
		var tp = Vector2i(floor((event.position.x - off.x) / TS), floor((event.position.y - off.y) / TS))
		if walkable(tp) and seen[idx(tp)] == 1 and tp != player:
			var d = _bfs(tp, true)
			if not d.has(player):
				d = _bfs(tp)
			if d.has(player):
				path.clear()
				var c = player
				while c != tp:
					var best = c
					for k in DIRS:
						var n: Vector2i = c + DIRS[k]
						if d.has(n) and d[n] < d.get(best, 99999):
							best = n
					if best == c: break
					path.append(best - c)
					c = best

func _process(delta: float) -> void:
	t += delta
	draw_pos = draw_pos.lerp(Vector2(player), minf(1.0, delta * 16.0))
	move_cd -= delta
	if not busy and bag == null and move_cd <= 0.0:
		var d = hold_dir
		for a in DIRS:
			if Input.is_action_pressed(a):
				d = DIRS[a]
		if d != Vector2i.ZERO:
			path.clear()
			_try_step(d)
			move_cd = 0.15
		elif path.size() > 0:
			var st: Vector2i = path.pop_front()
			_try_step(st)
			move_cd = 0.11
	if main_toast_later != "":
		main.toast(main_toast_later, UI.BAD)
		main_toast_later = ""
	for f in fx:
		f.t += delta
	fx = fx.filter(func(f): return f.t < 1.2)
	for p in parts:
		p.pos += p.vel * delta
		p.vel.y += 60 * delta
		p.life -= delta
	parts = parts.filter(func(p): return p.life > 0)
	queue_redraw()

func _try_step(d: Vector2i) -> void:
	var np = player + d
	if not walkable(np):
		return
	# bump into foe
	for f in foes:
		if f.alive and f.pos == np:
			_engage(f)
			return
	player = np
	Sfx.play("step", rng.randf_range(0.9, 1.1))
	_reveal()
	_on_tile()
	if busy: return
	_move_foes()

func _reveal() -> void:
	var r = 4
	var shade = Game.has_class_in_party("shadeblade")
	for y in range(player.y - r, player.y + r + 1):
		for x in range(player.x - r, player.x + r + 1):
			var p = Vector2i(x, y)
			if x < 0 or y < 0 or x >= W or y >= H: continue
			if (p - player).length_squared() <= r * r + 1:
				seen[idx(p)] = 1
				if shade and objs.has(p) and objs[p].type == "trap" and (p - player).length_squared() <= 5 and not objs[p].found:
					objs[p].found = true
					_float("Trap spotted!", Vector2(p), Color("ff9a9a"))

func _move_foes() -> void:
	for f in foes:
		if not f.alive or f.boss: continue
		if f.stun > 0:
			f.stun -= 1; continue
		var to: Vector2i = player - f.pos
		var step = Vector2i.ZERO
		if absi(to.x) + absi(to.y) <= 5 and rng.randf() < 0.8:
			if absi(to.x) > absi(to.y): step = Vector2i(signi(to.x), 0)
			else: step = Vector2i(0, signi(to.y))
			if not walkable(f.pos + step):
				step = Vector2i(signi(to.x), 0) if step.y != 0 else Vector2i(0, signi(to.y))
		elif rng.randf() < 0.35:
			step = DIRS.values()[rng.randi() % 4]
		var np: Vector2i = f.pos + step
		if step == Vector2i.ZERO or not walkable(np) or objs.has(np): continue
		var blocked = false
		for o in foes:
			if o != f and o.alive and o.pos == np: blocked = true
		if blocked: continue
		if np == player:
			_engage(f); return
		f.pos = np
	for f in foes:
		if f.alive and f.pos == player:
			_engage(f); return

func _engage(f: Dictionary) -> void:
	busy = true
	path.clear(); hold_dir = Vector2i.ZERO
	_engaged = f
	main.start_battle(f.ids, f.boss, self)

func on_battle_end(result: String) -> void:
	busy = false
	Sfx.music("dungeon")
	var f = _engaged
	_engaged = null
	if result == "win" and f:
		f.alive = false
		if f.boss:
			boss_dead = true
			if not floor_n in Game.cleared:
				Game.cleared.append(floor_n)
			if floor_n >= 5:
				Game.save_game()
				main.goto("ending")
				return
			Game.max_floor = maxi(Game.max_floor, floor_n + 1)
			objs[f.pos] = {"type": "stairs"}
			main.toast("The way down opens! B%d unlocked." % (floor_n + 1), UI.GOOD)
			Game.save_game()
	elif result == "flee" and f:
		f.stun = 4
	_refresh_hud()

func _on_tile() -> void:
	if not objs.has(player):
		return
	var o: Dictionary = objs[player]
	match o.type:
		"chest":
			if not o.open:
				o.open = true
				_loot()
		"trap":
			_trap(o)
		"fountain":
			if not o.used:
				o.used = true
				for h in Game.party_heroes():
					var s = Game.hero_stats(h)
					if int(h.hp) > 0:
						h.hp = mini(s.hp, int(h.hp) + int(s.hp * 0.5))
					h.mp = mini(s.mp, int(h.mp) + int(s.mp * 0.5))
				Sfx.play("heal")
				_burst(Vector2(player), Color("7fd8ff"), 18)
				main.toast("The fountain restores 50% HP and MP.", UI.GOOD)
				_refresh_hud()
		"portal":
			_choice("Return rune: go back to town? Monsters on this floor will respawn.", "Return to town", func():
				Game.save_game()
				main.goto("town"))
		"stairs":
			if floor_n < 5:
				_choice("Stairs lead down to B%d." % (floor_n + 1), "Descend", func():
					Sfx.play("stairs")
					Game.save_game()
					main.goto("dungeon", {"floor": floor_n + 1}), "Return to town", func():
					Game.save_game()
					main.goto("town"))

func _loot() -> void:
	Sfx.play("chest")
	Game.stats.chests += 1
	_burst(Vector2(player), UI.GOLD, 14)
	var g = rng.randi_range(15, 35) * floor_n
	Game.gold += g
	var msg = ["+%d G" % g]
	var roll = rng.randf()
	if roll < 0.32:
		var types = []
		for h in Game.party_heroes():
			types.append(Data.CLASSES[h.cls].weapon)
		var ty: String = types[rng.randi() % types.size()]
		var tier = clampi(fi + (1 if rng.randf() < 0.15 else 0), 0, 4)
		var w = Game.make_weapon(ty, tier, Game.roll_rarity(0, tier))
		Game.weapons.append(w)
		msg.append(Game.weapon_label(w))
		main.toast("Found: " + Game.weapon_label(w), Data.RARITY_COLOR[int(w.rarity)])
	elif roll < 0.47:
		var r: String = Data.RUNE_ORDER[rng.randi() % Data.RUNE_ORDER.size()]
		Game.add("runes", r)
		msg.append(Data.RUNES[r].name)
	elif roll < 0.75:
		var m: String = Data.FLOORS[fi].mat if rng.randf() < 0.6 else "runestone"
		var n = rng.randi_range(1, 3)
		Game.add("mats", m, n)
		msg.append("%s x%d" % [Data.MATERIALS[m].name, n])
	else:
		var it: String = ["tonic", "tonic", "ether", "hi_tonic", "clearwater", "ember_feather", "smoke_bomb"][rng.randi() % 7]
		Game.add("items", it)
		msg.append(Data.ITEMS[it].name)
	if rng.randf() < 0.5:
		Game.add("mats", "iron_ore", rng.randi_range(1, 2))
	_float(", ".join(msg), Vector2(player), UI.GOLD)
	_refresh_hud()

func _trap(o: Dictionary) -> void:
	o.found = true
	Sfx.play("trap")
	main.shake(6.0)
	match o.kind:
		"spikes", "rune":
			var pct = 0.12 if o.kind == "spikes" else 0.08
			for h in Game.party_heroes():
				if int(h.hp) > 0:
					var s = Game.hero_stats(h)
					h.hp = maxi(1, int(h.hp) - int(s.hp * pct))
					if o.kind == "rune":
						h.mp = maxi(0, int(h.mp) - int(s.mp * 0.2))
			_float("Spike trap!" if o.kind == "spikes" else "Drain rune! -MP", Vector2(player), UI.BAD)
			_burst(Vector2(player), UI.BAD, 12)
		"gas":
			for h in Game.party_heroes():
				if int(h.hp) > 0:
					var s = Game.hero_stats(h)
					h.hp = maxi(1, int(h.hp) - int(s.hp * 0.18))
			_float("Toxic gas!", Vector2(player), Color("8be04e"))
			_burst(Vector2(player), Color("8be04e"), 16)
		"alarm":
			_float("Alarm! Monsters approach!", Vector2(player), UI.BAD)
			for f in foes:
				if f.alive and not f.boss and (f.pos - player).length() < 10:
					f.stun = 0
			var near = player + Vector2i(1, 0)
			for k in DIRS:
				if walkable(player + DIRS[k]) and not objs.has(player + DIRS[k]):
					near = player + DIRS[k]; break
			foes.append({"pos": near, "ids": _group(), "boss": false, "stun": 1, "alive": true})
	objs.erase(player)
	_refresh_hud()

# ------------------------------------------------------------------ choice + bag panels
func _choice(text: String, a: String, cb_a: Callable, b := "Stay", cb_b := Callable()) -> void:
	busy = true
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c = CenterContainer.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.add_child(c)
	var p = UI.panel(10); c.add_child(p)
	var v = UI.vbox(6); v.custom_minimum_size.x = 240; p.add_child(v)
	v.add_child(UI.wrap(text, 12, UI.INK))
	v.add_child(UI.btn(a, func(): dim.queue_free(); busy = false; cb_a.call()))
	v.add_child(UI.btn(b, func():
		dim.queue_free(); busy = false
		if cb_b.is_valid(): cb_b.call()))
	if b != "Stay":
		v.add_child(UI.btn("Stay", func(): dim.queue_free(); busy = false))
	UI.focus_first(v)

func _open_bag() -> void:
	if busy or bag: return
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	bag = dim
	_fill_bag()

func _fill_bag(item := "") -> void:
	UI.clear(bag)
	var c = CenterContainer.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bag.add_child(c)
	var p = UI.panel(10); c.add_child(p)
	var v = UI.vbox(4); v.custom_minimum_size.x = 260; p.add_child(v)
	if item == "":
		v.add_child(UI.lbl("Bag", 14, UI.GOLD))
		var any = false
		for id in Data.ITEM_ORDER:
			var n = int(Game.items.get(id, 0))
			if n <= 0 or Data.ITEMS[id].target == "none": continue
			any = true
			var b = UI.btn("%s x%d — %s" % [Data.ITEMS[id].name, n, Data.ITEMS[id].desc], func(): _fill_bag(id), 0, 24)
			b.icon = Pix.item_icon(id)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 10)
			v.add_child(b)
		if not any:
			v.add_child(UI.lbl("No usable items.", 10, UI.DIM))
	else:
		var it: Dictionary = Data.ITEMS[item]
		v.add_child(UI.lbl("Use %s on..." % it.name, 13, UI.GOLD))
		for h in Game.party_heroes():
			var s = Game.hero_stats(h)
			var dead = int(h.hp) <= 0
			var b = UI.btn("%s  HP %d/%d  MP %d/%d%s" % [h.name, h.hp, s.hp, h.mp, s.mp, "  (KO)" if dead else ""], func(): _use_item(item, h), 0, 24)
			b.icon = Pix.hero(h.cls)
			b.disabled = dead != (it.target == "dead_ally")
			v.add_child(b)
	v.add_child(UI.btn("Close" if item == "" else "Back", func():
		if item == "": _close_bag()
		else: _fill_bag()))
	UI.focus_first(v)

func _use_item(id: String, h: Dictionary) -> void:
	var it: Dictionary = Data.ITEMS[id]
	var s = Game.hero_stats(h)
	if it.has("revive"):
		h.hp = int(s.hp * it.revive)
	if it.has("heal_pct"):
		h.hp = mini(s.hp, int(h.hp) + int(s.hp * it.heal_pct) + int(it.heal))
	if it.has("mp"):
		h.mp = mini(s.mp, int(h.mp) + int(it.mp))
	Game.items[id] = int(Game.items[id]) - 1
	Sfx.play("heal")
	_refresh_hud()
	_fill_bag()

func _close_bag() -> void:
	if bag:
		bag.queue_free()
		bag = null

# ------------------------------------------------------------------ fx + drawing
func _float(text: String, at: Vector2, col: Color) -> void:
	fx.append({"text": text, "pos": at, "t": 0.0, "col": col})

func _burst(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		parts.append({"pos": at * TS + Vector2(TS / 2, TS / 2), "vel": Vector2(rng.randf_range(-70, 70), rng.randf_range(-110, -30)), "life": rng.randf_range(0.4, 0.9), "col": col})

func _cam_offset() -> Vector2:
	return size / 2.0 - (draw_pos * TS + Vector2(TS / 2, TS / 2))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("08060e"))
	var off = _cam_offset()
	var x0 = maxi(0, int(-off.x / TS) - 1); var y0 := maxi(0, int(-off.y / TS) - 1)
	var x1 = mini(W, int((size.x - off.x) / TS) + 2); var y1 := mini(H, int((size.y - off.y) / TS) + 2)
	var acc = Color(Data.FLOORS[fi].pal.accent)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i = y * W + x
			if seen[i] == 0: continue
			var r = Rect2(off + Vector2(x, y) * TS, Vector2(TS, TS))
			if grid[i] == 1:
				draw_texture_rect(Pix.tile("floor", fi, deco[i]), r, false)
			else:
				var below_floor = y + 1 < H and grid[i + W] == 1
				draw_texture_rect(Pix.tile("wall" if below_floor else "walltop", fi), r, false)
	# objects
	for p in objs:
		if seen[idx(p)] == 0: continue
		var o: Dictionary = objs[p]
		var r = Rect2(off + Vector2(p) * TS, Vector2(TS, TS))
		match o.type:
			"chest": draw_texture_rect(Pix.tile("chest_open" if o.open else "chest", fi), r, false)
			"fountain": draw_texture_rect(Pix.tile("fountain_dry" if o.used else "fountain", fi), r, false)
			"portal":
				draw_texture_rect(Pix.tile("portal", fi), r, false)
				draw_circle(r.get_center(), 12 + 2 * sin(t * 3), Color(0.7, 0.5, 1, 0.18))
			"stairs":
				draw_texture_rect(Pix.tile("stairs", fi), r, false)
				draw_rect(r.grow(-2), Color(acc, 0.4 + 0.3 * sin(t * 4)), false, 2.0)
			"trap":
				if o.found: draw_texture_rect(Pix.tile("trap_hint", fi), r, false)
	# foes
	for f in foes:
		if not f.alive or seen[idx(f.pos)] == 0: continue
		var tex = Pix.enemy(f.ids[0])
		var bob = sin(t * 4 + f.pos.x) * 2
		var sz = 44.0 if f.boss else 30.0
		var c: Vector2 = off + Vector2(f.pos) * TS + Vector2(TS / 2, TS / 2 + bob)
		if f.boss:
			draw_circle(c, 22 + 2 * sin(t * 3), Color(1, 0.2, 0.3, 0.2))
		draw_texture_rect(tex, Rect2(c - Vector2(sz, sz) / 2, Vector2(sz, sz)), false, Color(0.6, 0.6, 0.7) if f.stun > 0 else Color.WHITE)
		if f.ids.size() > 1:
			draw_string(ThemeDB.fallback_font, c + Vector2(8, 14), "x%d" % f.ids.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.GOLD)
	# player
	var lead: Array = Game.party_heroes()
	var pc = off + draw_pos * TS + Vector2(TS / 2, TS / 2)
	draw_circle(pc + Vector2(0, 12), 9, Color(0, 0, 0, 0.35))
	if lead.size() > 0:
		draw_texture_rect(Pix.hero(lead[0].cls), Rect2(pc - Vector2(20, 26), Vector2(40, 40)), false)
	# light falloff / fog edge
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i = y * W + x
			if seen[i] == 0: continue
			var dd = (Vector2(x, y) - Vector2(player)).length()
			if dd > 4.2:
				draw_rect(Rect2(off + Vector2(x, y) * TS, Vector2(TS, TS)), Color(0, 0, 0.02, clampf((dd - 4.2) * 0.25 + 0.3, 0.0, 0.65)))
	for p in parts:
		draw_rect(Rect2(off + p.pos, Vector2(3, 3)), p.col)
	for f in fx:
		var a = 1.0 - f.t / 1.2
		var pos: Vector2 = off + f.pos * TS + Vector2(-40, -8 - f.t * 26)
		draw_string(ThemeDB.fallback_font, pos + Vector2(1, 1), f.text, HORIZONTAL_ALIGNMENT_CENTER, TS + 80, 11, Color(0, 0, 0, a))
		draw_string(ThemeDB.fallback_font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, TS + 80, 11, Color(f.col, a))
