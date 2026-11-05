extends Control
## Turn-based battle: initiative timeline, skills, elements, statuses, break gauges and the party combo gauge.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/Pix.gd")

signal picked(cmd)

var main
var enemy_ids: Array = []
var boss := false
var source
var units: Array = []
var heroes: Array = []
var enemies: Array = []
var fi := 0
var combo := 0.0
var chain := 0
var log_text := ""
var log_t := 0.0
var active = null
var targeting := {}
var hover = null
var auto := false
var speed := 1.0
var over := false
var t := 0.0
var floats: Array = []
var parts: Array = []
var rings: Array = []
var panel: PanelContainer
var cmd_box: Control
var top_btns: HBoxContainer
var auto_btn: Button
var rng := RandomNumberGenerator.new()
var enraged := false
var turn_no := 0

func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	fi = 0
	if source and source.get("fi") != null:
		fi = int(source.get("fi"))
	auto = bool(Game.get_meta("auto", false))
	speed = 2.0 if Game.settings.fast else 1.0
	Sfx.music("boss" if boss else "battle")
	_build_units()
	_build_ui()
	resized.connect(_layout)
	_layout()
	_run.call_deferred()

# ------------------------------------------------------------------ setup
func _build_units() -> void:
	for h in Game.party_heroes():
		var s = Game.hero_stats(h)
		var u = {"side": "hero", "h": h, "name": h.name, "cls": h.cls, "hp": int(h.hp), "mhp": s.hp, "mp": int(h.mp), "mmp": s.mp,
			"atk": s.atk, "mag": s.mag, "def": s.def, "res": s.res, "spd": s.spd, "crit": s.crit, "leech": s.leech, "brkb": s.brk,
			"elem": s.elem, "celem": Data.CLASSES[h.cls].elem, "weak": [], "resist": [], "st": {}, "alive": int(h.hp) > 0,
			"tex": Pix.hero(h.cls), "off": Vector2.ZERO, "flash": 0.0, "alpha": 1.0, "rect": Rect2()}
		units.append(u); heroes.append(u)
	var bonus = 1.0 + 0.25 * float(Game.cleared.count(fi + 1)) if boss and (fi + 1) in Game.cleared else 1.0
	var dmul: float = [1.0, 1.12, 1.25, 1.35, 1.45][clampi(fi, 0, 4)]
	for id in enemy_ids:
		var d: Dictionary = Data.ENEMIES[id]
		var u = {"side": "enemy", "id": id, "name": d.name, "hp": int(d.hp * bonus * (1.3 if d.get("boss", false) else 1.0)), "mhp": int(d.hp * bonus * (1.3 if d.get("boss", false) else 1.0)), "mp": 0, "mmp": 0,
			"atk": d.atk * bonus * dmul, "mag": d.mag * bonus * dmul, "def": d.def, "res": d.res, "spd": d.spd, "crit": 5, "leech": 0, "brkb": 0,
			"elem": "phys", "weak": d.weak, "resist": d.resist, "tough": int(d.tough), "mtough": int(d.tough), "st": {}, "alive": true,
			"boss": d.get("boss", false), "skills": d.skills, "tex": Pix.enemy(id), "off": Vector2.ZERO, "flash": 0.0, "alpha": 1.0, "rect": Rect2()}
		units.append(u); enemies.append(u)
	# initial initiative with a little jitter
	for u in units:
		u.t = 100.0 / _spd(u) * rng.randf_range(0.2, 1.0)

func _build_ui() -> void:
	panel = UI.panel(6)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	cmd_box = UI.vbox(4)
	panel.add_child(cmd_box)
	top_btns = UI.hbox(4)
	top_btns.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_btns.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_btns.offset_right = -4; top_btns.offset_top = 30
	add_child(top_btns)
	auto_btn = UI.btn("Auto: OFF", func():
		auto = not auto
		Game.set_meta("auto", auto)
		_upd_top()
		if auto and active and active.side == "hero" and targeting.is_empty():
			picked.emit(_auto_cmd(active)), 64, 22)
	auto_btn.focus_mode = Control.FOCUS_NONE
	auto_btn.add_theme_font_size_override("font_size", 10)
	top_btns.add_child(auto_btn)
	var sp = UI.btn("x1", func():
		Game.settings.fast = not Game.settings.fast
		speed = 2.0 if Game.settings.fast else 1.0
		Game.save_settings(); _upd_top(), 34, 22)
	sp.focus_mode = Control.FOCUS_NONE
	sp.add_theme_font_size_override("font_size", 10)
	sp.name = "Speed"
	top_btns.add_child(sp)
	var pb = UI.btn("II", func(): main.open_pause(), 28, 22)
	pb.focus_mode = Control.FOCUS_NONE
	top_btns.add_child(pb)
	_upd_top()
	_show_log_panel()

func _upd_top() -> void:
	auto_btn.text = "Auto: " + ("ON" if auto else "OFF")
	(top_btns.get_node("Speed") as Button).text = "x2" if speed > 1.5 else "x1"

func _layout() -> void:
	var W = size.x; var H := size.y
	var panel_h = 92.0 if H < 500 else 120.0
	panel.custom_minimum_size.y = panel_h
	panel.offset_top = -panel_h
	var ey0 = 50.0
	var py1 = H - panel_h - 18.0
	var py0 = py1 - 78.0
	var ey1 = py0 - 4.0
	var n = enemies.size()
	for i in n:
		var u: Dictionary = enemies[i]
		var sc = 3.0 if u.boss else 2.0
		if H > 500: sc += 1.0
		var sz = 32.0 * sc
		var cx = W * (i + 1) / (n + 1)
		var cy = (ey0 + ey1) / 2.0 + (8.0 if i % 2 == 1 and n > 2 else 0.0)
		sz = minf(sz, ey1 - ey0 - 26)
		u.rect = Rect2(cx - sz / 2, cy - sz / 2, sz, sz)
	var m = heroes.size()
	var cw = minf(150.0, (W - 12) / maxf(1, m) - 4)
	var x0 = (W - (cw + 4) * m) / 2.0
	for i in m:
		heroes[i].rect = Rect2(x0 + i * (cw + 4), py0, cw, 76)

# ------------------------------------------------------------------ helpers
func _spd(u: Dictionary) -> float:
	var s = float(u.spd)
	if u.st.has("haste"): s *= 1.5
	if u.st.has("slow"): s *= 0.6
	if u.st.has("shock"): s *= 0.75
	return maxf(1.0, s)

func _alive(list: Array) -> Array:
	return list.filter(func(x): return x.alive)

func _foes_of(u: Dictionary) -> Array:
	return _alive(enemies if u.side == "hero" else heroes)

func _allies_of(u: Dictionary) -> Array:
	return heroes if u.side == "hero" else enemies

func _timeline(n: int) -> Array:
	var sim = []
	for u in units:
		if u.alive: sim.append([u, float(u.t)])
	var out = []
	if sim.is_empty(): return out
	for k in n:
		var best = sim[0]
		for e in sim:
			if e[1] < best[1] - 0.001 or (absf(e[1] - best[1]) < 0.001 and e[0].side == "hero" and best[0].side != "hero"):
				best = e
		out.append(best[0])
		best[1] += 100.0 / _spd(best[0])
	return out

func _w(sec: float) -> void:
	await get_tree().create_timer(sec / speed).timeout

func say(s: String) -> void:
	log_text = s
	log_t = 0.0

func _float(u: Dictionary, text: String, col: Color, big := false) -> void:
	var r: Rect2 = u.rect
	floats.append({"text": text, "pos": Vector2(r.get_center().x + rng.randf_range(-10, 10), r.position.y + 10), "t": 0.0, "col": col, "big": big})

func _burst(at: Vector2, col: Color, n: int, spd := 120.0) -> void:
	for i in n:
		var a = rng.randf() * TAU
		parts.append({"pos": at, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(spd * 0.3, spd), "life": rng.randf_range(0.3, 0.8), "col": col, "sz": rng.randf_range(2, 4)})

func _tween_unit(u: Dictionary, key: String, to, dur: float) -> void:
	var from = u[key]
	var tw = create_tween()
	tw.tween_method(func(v): u[key] = v, from, to, dur / speed)

# ------------------------------------------------------------------ main loop
func _run() -> void:
	say("Battle start!" if not boss else "%s blocks the way!" % enemies[0].name)
	await _w(0.6)
	while not over:
		if not is_inside_tree(): return
		var u = _timeline(1)[0] if _timeline(1).size() > 0 else null
		if u == null: break
		active = u
		turn_no += 1
		var skip: bool = await _start_turn(u)
		if _check_end(): break
		if not skip and u.alive:
			var cmd: Dictionary
			if u.side == "hero":
				cmd = await _hero_turn(u)
			else:
				cmd = _enemy_ai(u)
			if over or not is_inside_tree(): return
			await _execute(u, cmd)
			if not is_inside_tree(): return
		else:
			u.t += 100.0 / _spd(u)
		if _check_end(): break
		await _w(0.25)
	active = null

func _start_turn(u: Dictionary) -> bool:
	var st: Dictionary = u.st
	var skip = false
	if st.has("broken"):
		st.erase("broken")
		u.tough = u.mtough
		say("%s recovers from the break." % u.name)
		await _w(0.5)
		return true
	if u.side == "enemy":
		chain = 0
	if st.has("poison"):
		var d = int(u.mhp * (0.03 if u.get("boss", false) else 0.07)) + 2
		_damage(u, d, Data.STATUSES.poison.color, false)
		await _w(0.3)
	if st.has("burn") and u.alive:
		var d = int(u.mhp * (0.025 if u.get("boss", false) else 0.05)) + 2
		_damage(u, d, Data.STATUSES.burn.color, false)
		await _w(0.3)
	if st.has("regen") and u.alive:
		_heal(u, int(u.mhp * 0.09) + 4)
		await _w(0.25)
	if st.has("freeze") and u.alive:
		skip = true
		_float(u, "Frozen!", Data.STATUSES.freeze.color)
		say("%s is frozen solid!" % u.name)
		await _w(0.5)
	for k in st.keys():
		st[k] = int(st[k]) - 1
		if st[k] <= 0:
			st.erase(k)
	return skip or not u.alive

func _check_end() -> bool:
	if over: return true
	if _alive(enemies).is_empty():
		over = true
		_victory()
		return true
	if _alive(heroes).is_empty():
		over = true
		_defeat()
		return true
	return false

# ------------------------------------------------------------------ hero input
func _hero_turn(u: Dictionary) -> Dictionary:
	say("%s's turn." % u.name)
	if auto:
		await _w(0.35)
		return _auto_cmd(u)
	_menu_main(u)
	var cmd = await picked
	targeting = {}
	_show_log_panel()
	return cmd

func _clear_cmd() -> void:
	UI.clear(cmd_box)

func _show_log_panel() -> void:
	_clear_cmd()
	var l = UI.lbl("", 11, UI.DIM)
	l.name = "Log"
	cmd_box.add_child(l)

func _menu_main(u: Dictionary) -> void:
	_clear_cmd()
	var head = UI.hbox(6)
	cmd_box.add_child(head)
	head.add_child(UI.lbl("%s  HP %d/%d  MP %d/%d" % [u.name, u.hp, u.mhp, u.mp, u.mmp], 11, UI.GOLD))
	var g = GridContainer.new()
	g.columns = 3 if size.x < 500 else 6
	cmd_box.add_child(g)
	var bw = (size.x - 40) / g.columns - 4
	g.add_child(UI.btn("Attack", func(): _pick_target(u, "attack"), bw, 28))
	g.add_child(UI.btn("Skills", func(): _menu_skills(u), bw, 28))
	g.add_child(UI.btn("Items", func(): _menu_items(u), bw, 28))
	g.add_child(UI.btn("Guard", func(): picked.emit({"type": "guard"}), bw, 28))
	var bb = UI.btn("RUNE BURST" if combo >= 100 else "Burst %d%%" % int(combo), func(): picked.emit({"type": "burst"}), bw, 28)
	bb.disabled = combo < 100
	if combo >= 100:
		bb.add_theme_color_override("font_color", UI.GOLD)
		bb.add_theme_stylebox_override("normal", UI.sb(Color("5a3a1a"), UI.GOLD))
	g.add_child(bb)
	var fb = UI.btn("Flee", func(): picked.emit({"type": "flee"}), bw, 28)
	fb.disabled = boss
	g.add_child(fb)
	UI.focus_first(g)

func _menu_skills(u: Dictionary) -> void:
	_clear_cmd()
	var g = GridContainer.new()
	g.columns = 2 if size.x < 500 else 3
	var bw = (size.x - 40) / g.columns - 4
	var sc = UI.scroll(g)
	cmd_box.add_child(sc)
	for sk in Game.skills_for(u.h):
		var d: Dictionary = Data.SKILLS[sk]
		var el: String = d.get("elem", "")
		var b = UI.btn("%s  %dMP" % [d.name, int(d.mp)], func(): _pick_target(u, sk), bw, 26)
		b.tooltip_text = d.desc
		b.add_theme_font_size_override("font_size", 10)
		if el != "" and el != "phys":
			b.add_theme_color_override("font_color", Data.ELEM_COLOR[el])
		b.disabled = u.mp < int(d.mp)
		b.focus_entered.connect(func(): say(d.desc))
		b.mouse_entered.connect(func(): say(d.desc))
		g.add_child(b)
	g.add_child(UI.btn("Back", func(): _menu_main(u), bw, 26))
	UI.focus_first(g)

func _menu_items(u: Dictionary) -> void:
	_clear_cmd()
	var g = GridContainer.new()
	g.columns = 2 if size.x < 500 else 3
	var bw = (size.x - 40) / g.columns - 4
	cmd_box.add_child(UI.scroll(g))
	for id in Data.ITEM_ORDER:
		var n = int(Game.items.get(id, 0))
		if n <= 0: continue
		var it: Dictionary = Data.ITEMS[id]
		if it.get("escape", false) and boss: continue
		var b = UI.btn("%s x%d" % [it.name, n], func():
			if it.target == "none":
				picked.emit({"type": "item", "id": id, "target": u})
			else:
				_pick_target(u, "", id), bw, 26)
		b.icon = Pix.item_icon(id)
		b.add_theme_font_size_override("font_size", 10)
		b.focus_entered.connect(func(): say(it.desc))
		b.mouse_entered.connect(func(): say(it.desc))
		g.add_child(b)
	g.add_child(UI.btn("Back", func(): _menu_main(u), bw, 26))
	UI.focus_first(g)

func _pick_target(u: Dictionary, sk: String, item := "") -> void:
	var tg: String = Data.ITEMS[item].target if item != "" else Data.SKILLS[sk].target
	var cands: Array
	match tg:
		"enemy": cands = _alive(enemies)
		"ally": cands = _alive(heroes)
		"dead_ally": cands = heroes.filter(func(x): return not x.alive)
		_:
			picked.emit({"type": "item" if item != "" else "skill", "id": item if item != "" else sk, "target": u})
			return
	if cands.is_empty():
		Sfx.play("deny"); say("No valid target."); return
	var start = 0
	if tg == "ally":
		var low = 1.0
		for i in cands.size():
			var f: float = float(cands[i].hp) / cands[i].mhp
			if f < low: low = f; start = i
	targeting = {"u": u, "sk": sk, "item": item, "cands": cands, "i": start}
	_clear_cmd()
	var h = UI.hbox(6)
	cmd_box.add_child(h)
	var nm: String = Data.ITEMS[item].name if item != "" else Data.SKILLS[sk].name
	h.add_child(UI.lbl("%s — choose a target (tap it, or arrows + Enter)" % nm, 11, UI.GOLD))
	var hb = UI.hbox(6)
	cmd_box.add_child(hb)
	hb.add_child(UI.btn("Confirm", _confirm_target, 90, 28))
	hb.add_child(UI.btn("Back", func(): targeting = {}; _menu_main(u), 90, 28))
	get_viewport().gui_release_focus()

func _confirm_target() -> void:
	if targeting.is_empty(): return
	var tg = targeting.cands[targeting.i]
	var cmd = {"type": "item" if targeting.item != "" else "skill", "id": targeting.item if targeting.item != "" else targeting.sk, "target": tg}
	targeting = {}
	Sfx.play("click")
	picked.emit(cmd)

func _unhandled_input(event: InputEvent) -> void:
	if targeting.is_empty(): return
	var n: int = targeting.cands.size()
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		targeting.i = (targeting.i - 1 + n) % n; Sfx.play("move"); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		targeting.i = (targeting.i + 1) % n; Sfx.play("move"); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm_target(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		var u = targeting.u
		targeting = {}
		_menu_main(u)
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = null
		for u in units:
			if u.rect.has_point(event.position): hover = u
	if targeting.is_empty(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in targeting.cands.size():
			if targeting.cands[i].rect.grow(4).has_point(event.position):
				if targeting.i == i or true:
					targeting.i = i
					_confirm_target()
				return

# ------------------------------------------------------------------ AI
func _auto_cmd(u: Dictionary) -> Dictionary:
	if combo >= 100:
		return {"type": "burst"}
	var foes = _alive(enemies)
	var dead = heroes.filter(func(x): return not x.alive)
	var skills = Game.skills_for(u.h)
	var low = null
	for h in _alive(heroes):
		if float(h.hp) / h.mhp < 0.45 and (low == null or h.hp < low.hp): low = h
	if dead.size() > 0 and "revive" in skills and u.mp >= Data.SKILLS.revive.mp:
		return {"type": "skill", "id": "revive", "target": dead[0]}
	if dead.size() > 0 and int(Game.items.get("ember_feather", 0)) > 0 and rng.randf() < 0.5:
		return {"type": "item", "id": "ember_feather", "target": dead[0]}
	if low:
		for sk in ["sanctuary", "mend", "repair_drone"]:
			if sk in skills and u.mp >= Data.SKILLS[sk].mp:
				return {"type": "skill", "id": sk, "target": low}
		if int(Game.items.get("tonic", 0)) > 0 and float(low.hp) / low.mhp < 0.3:
			return {"type": "item", "id": "tonic", "target": low}
	# best offensive skill vs a weakness
	var best = {"type": "skill", "id": "attack", "target": foes[rng.randi() % foes.size()]}
	var best_score = 1.0
	for sk in skills:
		var d: Dictionary = Data.SKILLS[sk]
		if u.mp < int(d.mp) or not d.kind in ["phys", "mag"]: continue
		for f in foes:
			var sc = float(d.power) * (1.6 if d.elem in f.weak else (0.5 if d.elem in f.resist else 1.0))
			if d.target == "all_enemies": sc *= 0.8 * foes.size()
			if d.target == "random_enemies": sc *= 3.0
			if sc > best_score and rng.randf() < 0.85:
				best_score = sc
				best = {"type": "skill", "id": sk, "target": f}
	if best.id == "attack" and u.mp < 6 and int(Game.items.get("ether", 0)) > 0 and rng.randf() < 0.3:
		return {"type": "item", "id": "ether", "target": u}
	return best

func _enemy_ai(u: Dictionary) -> Dictionary:
	var sks: Array = u.skills.duplicate()
	if u.boss and not enraged and u.hp < u.mhp * 0.5:
		enraged = true
		u.st["atkup"] = 99
		say("%s is ENRAGED!" % u.name)
		main.shake(8.0)
	var pick: String = sks[rng.randi() % sks.size()]
	for i in 3:
		var d: Dictionary = Data.SKILLS[pick]
		if d.kind == "heal" and u.hp > u.mhp * 0.5:
			pick = sks[rng.randi() % sks.size()]
		elif d.kind == "buff" and u.st.has("atkup"):
			pick = sks[rng.randi() % sks.size()]
		else:
			break
	var d2: Dictionary = Data.SKILLS[pick]
	if (d2.kind == "heal" and u.hp > u.mhp * 0.5) or (d2.kind == "buff" and u.st.has("atkup")):
		pick = "e_bite" if not u.boss else "e_slam"
	var foes = _alive(heroes)
	var tgt = foes[rng.randi() % foes.size()]
	var taunt = foes.filter(func(x): return x.st.has("taunt"))
	if taunt.size() > 0 and rng.randf() < 0.75:
		tgt = taunt[0]
	elif rng.randf() < 0.3:
		for f in foes:
			if f.hp < tgt.hp: tgt = f
	return {"type": "skill", "id": pick, "target": tgt}

# ------------------------------------------------------------------ execution
func _execute(u: Dictionary, cmd: Dictionary) -> void:
	var cost = 1.0
	match cmd.type:
		"guard":
			u.st["guard"] = 1
			u.mp = mini(u.mmp, u.mp + int(u.mmp * 0.1))
			_float(u, "Guard", Data.STATUSES.guard.color)
			say("%s guards and focuses (+MP)." % u.name)
			Sfx.play("buff")
			cost = 0.6
			await _w(0.4)
		"flee":
			cost = 1.0
			if rng.randf() < 0.65:
				say("Got away safely!")
				Sfx.play("stairs")
				await _w(0.6)
				_finish("flee")
				return
			say("Couldn't escape!")
			Sfx.play("deny")
			await _w(0.6)
		"item":
			await _use_item(u, cmd)
			if over: return
		"burst":
			combo = 0.0
			var d: Dictionary = Data.SKILLS.burst.duplicate()
			d.elem = u.celem
			await _use_skill(u, "burst", d, cmd.get("target", u))
		"skill":
			var d: Dictionary = Data.SKILLS[cmd.id]
			u.mp -= int(d.get("mp", 0))
			cost = float(d.get("cost", 1.0))
			await _use_skill(u, cmd.id, d, cmd.target)
	u.t += 100.0 / _spd(u) * cost

func _use_item(u: Dictionary, cmd: Dictionary) -> void:
	var it: Dictionary = Data.ITEMS[cmd.id]
	Game.items[cmd.id] = int(Game.items.get(cmd.id, 0)) - 1
	var tg = cmd.target
	say("%s uses %s." % [u.name, it.name])
	if it.get("escape", false):
		Sfx.play("stairs")
		await _w(0.5)
		_finish("flee")
		return
	if it.has("revive") and not tg.alive:
		tg.alive = true
		tg.hp = int(tg.mhp * it.revive)
		_tween_unit(tg, "alpha", 1.0, 0.3)
		_float(tg, "Revived!", UI.GOOD)
		Sfx.play("heal")
	if it.has("heal_pct") and tg.alive:
		_heal(tg, int(tg.mhp * it.heal_pct) + int(it.heal))
	if it.has("mp") and tg.alive:
		tg.mp = mini(tg.mmp, tg.mp + int(it.mp))
		_float(tg, "+%d MP" % int(it.mp), Color("5fb4ff"))
		Sfx.play("heal")
	if it.get("cleanse", false):
		_cleanse(tg)
	await _w(0.5)

func _cleanse(u: Dictionary) -> void:
	for k in u.st.keys():
		if Data.STATUSES[k].bad and k != "broken":
			u.st.erase(k)
	_float(u, "Cleansed", Color("7fffd8"))

func _use_skill(u: Dictionary, id: String, d: Dictionary, target) -> void:
	if id != "attack":
		say("%s — %s!" % [u.name, d.name])
	else:
		say("%s attacks." % u.name)
	# wind-up lunge
	var dir = -1.0 if u.side == "hero" else 1.0
	_tween_unit(u, "off", Vector2(0, 14 * dir), 0.12)
	await _w(0.14)
	var targets: Array = []
	match d.target:
		"enemy":
			targets = [target if target.alive else (_foes_of(u)[0] if _foes_of(u).size() > 0 else null)]
		"all_enemies":
			targets = _foes_of(u)
		"random_enemies":
			for i in int(d.get("hits", 3)):
				var f = _foes_of(u)
				if f.size() > 0: targets.append(f[rng.randi() % f.size()])
		"ally":
			targets = [target]
		"all_allies":
			targets = _alive(_allies_of(u))
		"self":
			targets = [u]
		"dead_ally":
			targets = [target]
	if id == "burst":
		main.shake(10.0)
		Sfx.play("burst")
		rings.append({"pos": size / 2.0 - Vector2(0, 40), "t": 0.0, "col": Data.ELEM_COLOR.get(d.elem, UI.GOLD), "r": 260.0})
		await _w(0.3)
	var chained = false
	for tg in targets:
		if tg == null: continue
		match d.kind:
			"phys", "mag":
				if not tg.alive and d.target == "random_enemies": continue
				if not tg.alive: continue
				_strike(u, tg, d)
				chained = true
			"heal":
				if d.get("revive", false):
					if not tg.alive:
						tg.alive = true
						tg.hp = int(tg.mhp * d.power)
						tg.st = {}
						_tween_unit(tg, "alpha", 1.0, 0.3)
						_float(tg, "Revived!", UI.GOOD)
						Sfx.play("heal")
				elif tg.alive:
					_heal(tg, int(u.mag * float(d.power) * 1.6 + 8))
					if d.get("cleanse", false): _cleanse(tg)
					_burst(tg.rect.get_center(), UI.GOOD, 10, 60)
				if d.has("status") and tg.alive: _apply_status(tg, d.status)
			"buff":
				if tg.alive:
					if d.has("status"): _apply_status(tg, d.status, true)
					if d.has("status2"): _apply_status(tg, d.status2, true)
					Sfx.play("buff")
					_burst(tg.rect.get_center(), Data.STATUSES[d.status[0]].color, 8, 50)
		await _w(0.16 if targets.size() > 1 else 0.3)
	if chained and u.side == "hero":
		chain += 1
	_tween_unit(u, "off", Vector2.ZERO, 0.15)
	await _w(0.25)

func _strike(u: Dictionary, tg: Dictionary, d: Dictionary) -> void:
	var elem: String = d.get("elem", "")
	if elem == "": elem = u.elem
	var phys: bool = d.kind == "phys"
	var A: float = float(u.atk) if phys else float(u.mag)
	if d == Data.SKILLS.burst or (d.name == "RUNE BURST"):
		A = maxf(u.atk, u.mag)
	if u.st.has("atkup"): A *= 1.3
	if u.st.has("weaken"): A *= 0.7
	if phys and u.st.has("burn"): A *= 0.85
	var D: float = float(tg.def) if phys else float(tg.res)
	# evade
	if tg.st.has("evade") and rng.randf() < 0.6 and d.target != "all_enemies":
		_float(tg, "Miss", Color("c9b0ff"))
		Sfx.play("miss")
		return
	var dmg = A * float(d.power) * 1.5 * 50.0 / (50.0 + D)
	var weak: bool = elem in tg.weak
	var res: bool = elem in tg.resist
	if weak: dmg *= 1.6
	if res: dmg *= 0.5
	if tg.st.has("broken"): dmg *= 1.5
	if tg.st.has("guard"): dmg *= 0.5
	var crit = rng.randf() * 100.0 < float(u.crit) + float(d.get("crit", 0))
	if crit: dmg *= 1.6
	if u.side == "hero": dmg *= 1.0 + 0.06 * mini(chain, 8)
	else: dmg *= 1.55
	dmg *= rng.randf_range(0.92, 1.08)
	var amount = maxi(1, int(dmg))
	var col: Color = Data.ELEM_COLOR.get(elem, Color.WHITE)
	_damage(tg, amount, Color("ffd36b") if crit else (Color("ff8a5a") if weak else Color.WHITE), crit or weak)
	if weak: _float(tg, "WEAK!", col)
	elif res: _float(tg, "Resist", Color("9aa0c0"))
	if crit: _float(tg, "CRITICAL", UI.GOLD)
	_burst(tg.rect.get_center(), col, 14 if crit else 8)
	rings.append({"pos": tg.rect.get_center(), "t": 0.0, "col": col, "r": 30.0 + (20.0 if crit else 0.0)})
	Sfx.play("crit" if crit else ("hit" if u.side == "hero" else "ehit"), rng.randf_range(0.9, 1.1))
	if elem == "storm": Sfx.play("storm")
	elif d.kind == "mag": Sfx.play("magic", 1.2)
	main.shake(5.0 if crit or tg.side == "hero" else 2.5)
	# lifesteal / drain
	var leech = float(u.leech) / 100.0 + (0.5 if d.get("drain", false) else 0.0)
	if leech > 0 and u.alive:
		_heal(u, int(amount * leech), false)
	# statuses
	if d.has("status") and tg.alive: _apply_status(tg, d.status)
	if d.has("status2") and tg.alive: _apply_status(tg, d.status2)
	# break + combo
	if u.side == "hero":
		combo = minf(100.0, combo + (12.0 if weak else 6.0) + (4.0 if crit else 0.0))
		if tg.side == "enemy" and tg.alive and not tg.st.has("broken") and not res:
			var b = int(d.get("brk", 1)) + int(u.brkb)
			b = b * 2 if weak else int(ceil(b / 2.0))
			tg.tough = maxi(0, int(tg.tough) - b)
			if tg.tough <= 0:
				tg.st["broken"] = 99
				combo = minf(100.0, combo + 20.0)
				_float(tg, "BREAK!", Color.WHITE, true)
				Sfx.play("break")
				main.shake(9.0)
				rings.append({"pos": tg.rect.get_center(), "t": 0.0, "col": Color.WHITE, "r": 80.0})
				say("%s is BROKEN! It loses its next turn and takes +50%% damage." % tg.name)

func _apply_status(tg: Dictionary, s: Array, force := false) -> void:
	var id: String = s[0]
	var chance = float(s[1])
	if tg.get("boss", false) and id in ["freeze", "slow", "shock"]:
		chance *= 0.4
	if not force and rng.randf() * 100.0 >= chance:
		return
	tg.st[id] = maxi(int(tg.st.get(id, 0)), int(s[2]))
	_float(tg, Data.STATUSES[id].name, Data.STATUSES[id].color)
	if Data.STATUSES[id].bad: Sfx.play("debuff")

func _damage(u: Dictionary, amount: int, col: Color, big: bool) -> void:
	u.hp = maxi(0, u.hp - amount)
	_float(u, str(amount), col, big)
	u.flash = 1.0
	_tween_unit(u, "flash", 0.0, 0.3)
	if u.hp <= 0 and u.alive:
		u.alive = false
		u.st = {}
		if u.side == "enemy":
			Game.stats.kills += 1
			_tween_unit(u, "alpha", 0.0, 0.5)
			_burst(u.rect.get_center(), Color(Data.ENEMIES[u.id].pal[0]), 24, 160)
		else:
			_tween_unit(u, "alpha", 0.45, 0.3)
			_float(u, "KO", UI.BAD, true)

func _heal(u: Dictionary, amount: int, show := true) -> void:
	if not u.alive: return
	var before: int = u.hp
	u.hp = mini(u.mhp, u.hp + amount)
	if show or u.hp - before > 0:
		_float(u, "+%d" % (u.hp - before), UI.GOOD)
	if show: Sfx.play("heal")

# ------------------------------------------------------------------ end of battle
func _sync_back() -> void:
	for u in heroes:
		u.h.hp = u.hp if u.alive else 0
		u.h.mp = u.mp

func _finish(result: String) -> void:
	over = true
	_sync_back()
	main.end_battle(result)

func _victory() -> void:
	Sfx.music("")
	Sfx.play("victory")
	_sync_back()
	var xp = 0; var gold := 0
	var drops = {}
	for e in enemies:
		var d: Dictionary = Data.ENEMIES[e.id]
		xp += int(d.xp); gold += int(d.gold)
		for dr in d.drops:
			if rng.randi() % 100 < int(dr[1]):
				drops[dr[0]] = int(drops.get(dr[0], 0)) + (rng.randi_range(1, 2) if d.get("boss", false) else 1)
	Game.gold += gold
	Game.stats.battles += 1
	Game.stats.wins += 1
	for m in drops:
		Game.add("mats", m, drops[m])
	var lines = ["+%d XP   +%d G" % [xp, gold]]
	for u in heroes:
		var gained = xp if u.alive else xp / 2
		var ups = Game.gain_xp(u.h, gained)
		if ups > 0:
			lines.append("%s reached Lv%d!" % [u.name, int(u.h.lvl)])
			if not u.alive:
				u.h.hp = 0
	var dl = []
	for m in drops:
		dl.append("%s x%d" % [Data.MATERIALS[m].name, drops[m]])
	if dl.size() > 0:
		lines.append("Loot: " + ", ".join(dl))
	if boss:
		var w = Game.make_weapon(Data.CLASSES[heroes[rng.randi() % heroes.size()].cls].weapon, clampi(fi + 1, 0, 4), maxi(2, Game.roll_rarity(1, fi)))
		Game.weapons.append(w)
		lines.append("Boss trophy: " + Game.weapon_label(w))
	for l in lines:
		if "reached" in l:
			Sfx.play("levelup"); break
	_result_panel("VICTORY!", UI.GOLD, lines, "Continue", func(): main.end_battle("win"))

func _defeat() -> void:
	Sfx.music("")
	Sfx.play("defeat")
	_sync_back()
	_result_panel("DEFEATED", UI.BAD, ["Your party has fallen...", "You will wake in Emberhold, but lose half your gold."], "Return to town", func(): main.end_battle("lose"))

func _result_panel(title: String, col: Color, lines: Array, btn: String, cb: Callable) -> void:
	await _w(0.6)
	if not is_inside_tree(): return
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c = CenterContainer.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.add_child(c)
	var p = UI.panel(12); c.add_child(p)
	var v = UI.vbox(4); v.custom_minimum_size.x = 260; p.add_child(v)
	v.add_child(UI.lbl(title, 22, col, HORIZONTAL_ALIGNMENT_CENTER))
	for l in lines:
		var lab = UI.wrap(l, 11, UI.INK)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
	var b = UI.btn(btn, cb)
	b.name = "ResultButton"
	v.add_child(b)
	b.grab_focus()
	p.pivot_offset = Vector2(130, 60)
	p.scale = Vector2(0.5, 0.5)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ drawing
func _process(delta: float) -> void:
	t += delta
	log_t += delta
	for f in floats: f.t += delta * speed
	floats = floats.filter(func(f): return f.t < 1.1)
	for p in parts:
		p.pos += p.vel * delta
		p.vel *= 0.92
		p.life -= delta
	parts = parts.filter(func(p): return p.life > 0)
	for r in rings: r.t += delta * 2.5
	rings = rings.filter(func(r): return r.t < 1.0)
	var l = cmd_box.get_node_or_null("Log")
	if l: l.text = log_text
	queue_redraw()

func _draw() -> void:
	var W = size.x; var H := size.y
	var pal: Dictionary = Data.FLOORS[fi].pal
	for i in 12:
		draw_rect(Rect2(0, H * i / 12.0, W, H / 12.0 + 1), Color(pal.wall2).darkened(0.5).lerp(Color(pal.floor), float(i) / 12.0))
	var wall = Pix.tile("wall", fi)
	var fl = Pix.tile("floor", fi)
	var horizon = H * 0.36
	for x in range(0, int(W) + 32, 32):
		for y in range(int(horizon) - 96, int(horizon), 32):
			draw_texture_rect(wall, Rect2(x, y, 32, 32), false, Color(0.55, 0.55, 0.6))
		for y in range(int(horizon), int(H), 32):
			draw_texture_rect(fl, Rect2(x, y, 32, 32), false, Color(0.7, 0.7, 0.75))
	draw_rect(Rect2(0, 0, W, horizon - 96), Color(0, 0, 0, 0.6))
	if boss:
		draw_rect(Rect2(0, 0, W, H), Color(0.5, 0, 0.1, 0.12 + 0.05 * sin(t * 2)))
	_draw_timeline()
	# enemies
	for u in enemies:
		if u.alpha <= 0.01: continue
		var r: Rect2 = u.rect
		r.position += u.off + Vector2(0, sin(t * 2.5 + r.position.x) * 2)
		draw_circle(Vector2(r.get_center().x, r.end.y - 2), r.size.x * 0.3, Color(0, 0, 0, 0.3 * u.alpha))
		var mod = Color(1, 1, 1, u.alpha).lerp(Color(1, 0.3, 0.3, u.alpha), u.flash)
		if u.st.has("broken"): mod = mod.lerp(Color(0.6, 0.6, 1.0, u.alpha), 0.4)
		draw_texture_rect(u.tex, r, false, mod)
		if _is_target(u) or (hover == u and u.alive):
			_draw_cursor(r)
		if not u.alive: continue
		var by = r.position.y - 14
		var bw = maxf(56.0, r.size.x)
		var bx = r.get_center().x - bw / 2
		draw_string(ThemeDB.fallback_font, Vector2(bx, by - 2), u.name, HORIZONTAL_ALIGNMENT_CENTER, bw, 10, Color("f2ead8"))
		UI.bar(Rect2(bx, by + 1, bw, 5), float(u.hp) / u.mhp, Color("ff5a5a"), self)
		# break gauge pips
		var pw = bw / maxf(1, u.mtough)
		for i in u.mtough:
			var c = Color("ffffff") if i < u.tough else Color(0.2, 0.2, 0.3)
			if u.st.has("broken"): c = Color(1, 0.8, 0.3, 0.5 + 0.5 * sin(t * 10))
			draw_rect(Rect2(bx + i * pw + 0.5, by + 7, maxf(1, pw - 1), 3), c)
		# weaknesses
		var wx = bx
		for e in u.weak:
			draw_rect(Rect2(wx, r.end.y + 1, 7, 7), Data.ELEM_COLOR[e])
			draw_rect(Rect2(wx, r.end.y + 1, 7, 7), Color.BLACK, false, 1.0)
			wx += 9
		_draw_status(u.st, Vector2(r.end.x - 2, r.position.y))
	# heroes
	for u in heroes:
		var r: Rect2 = u.rect
		var raised = (active == u and not over)
		var rr = r
		rr.position += u.off + (Vector2(0, -6) if raised else Vector2.ZERO)
		draw_rect(rr, Color(0.07, 0.05, 0.12, 0.88))
		draw_rect(rr, UI.GOLD if raised else Color("5a4890"), false, 2.0 if raised else 1.0)
		var mod = Color(1, 1, 1, u.alpha).lerp(Color(1, 0.3, 0.3, 1), u.flash)
		if not u.alive: mod = Color(0.4, 0.4, 0.45, 0.8)
		var ts = minf(40.0, rr.size.x * 0.32)
		draw_texture_rect(u.tex, Rect2(rr.position + Vector2(2, 4), Vector2(ts, ts)), false, mod)
		var tx = rr.position.x + ts + 5
		var tw = rr.end.x - tx - 4
		draw_string(ThemeDB.fallback_font, Vector2(tx, rr.position.y + 13), u.name, HORIZONTAL_ALIGNMENT_LEFT, tw, 11, Color("f2ead8") if u.alive else UI.BAD)
		draw_string(ThemeDB.fallback_font, Vector2(tx, rr.position.y + 25), Data.CLASSES[u.cls].name, HORIZONTAL_ALIGNMENT_LEFT, tw, 9, Data.ELEM_COLOR[u.celem])
		var bx = rr.position.x + 4
		var bw = rr.size.x - 8
		UI.bar(Rect2(bx, rr.position.y + 48, bw, 7), float(u.hp) / u.mhp, Color("7be06a") if float(u.hp) / u.mhp > 0.35 else Color("ff6a6a"), self)
		draw_string(ThemeDB.fallback_font, Vector2(bx, rr.position.y + 46), "%d/%d" % [u.hp, u.mhp], HORIZONTAL_ALIGNMENT_RIGHT, bw, 9, Color("f2ead8"))
		UI.bar(Rect2(bx, rr.position.y + 58, bw, 5), float(u.mp) / maxf(1, u.mmp), Color("5fb4ff"), self)
		draw_string(ThemeDB.fallback_font, Vector2(bx, rr.position.y + 72), "MP %d" % u.mp, HORIZONTAL_ALIGNMENT_LEFT, bw, 9, Color("9ac8ff"))
		_draw_status(u.st, Vector2(rr.end.x - 3, rr.position.y + 66))
		if _is_target(u) or (hover == u and not targeting.is_empty()):
			_draw_cursor(rr)
	# combo gauge
	var gy = size.y - panel.size.y - 15
	var gw = minf(300.0, W - 120)
	var gx = 6.0
	draw_string(ThemeDB.fallback_font, Vector2(gx, gy + 9), "COMBO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.GOLD)
	var full = combo >= 100.0
	UI.bar(Rect2(gx + 44, gy + 1, gw, 9), combo / 100.0, Color(1, 0.8, 0.3).lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(t * 8)) if full else Color("c47bff"), self)
	if full:
		draw_string(ThemeDB.fallback_font, Vector2(gx + 50, gy + 9), "RUNE BURST READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("1a0e08"))
	if chain > 1:
		draw_string(ThemeDB.fallback_font, Vector2(gx + gw + 52, gy + 10), "CHAIN x%d (+%d%%)" % [chain, 6 * mini(chain, 8)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ff9a3a"))
	# fx
	for r in rings:
		draw_arc(r.pos, r.r * r.t, 0, TAU, 32, Color(r.col, 1.0 - r.t), 3.0)
	for p in parts:
		draw_rect(Rect2(p.pos, Vector2(p.sz, p.sz)), p.col)
	for f in floats:
		var a = clampf(1.4 - f.t * 1.3, 0, 1)
		var fs = 18 if f.big else 13
		var pos: Vector2 = f.pos + Vector2(-60, -f.t * 30 - (6 * sin(f.t * 8) if f.big else 0))
		draw_string(ThemeDB.fallback_font, pos + Vector2(1, 1), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, fs, Color(0, 0, 0, a))
		draw_string(ThemeDB.fallback_font, pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, fs, Color(f.col, a))

func _is_target(u) -> bool:
	return not targeting.is_empty() and targeting.cands[targeting.i] == u

func _draw_cursor(r: Rect2) -> void:
	var c = UI.GOLD
	var o = 3.0 + 2.0 * sin(t * 8)
	var rr = r.grow(o)
	var l = 8.0
	for corner in [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)]:
		var sx = 1.0 if corner.x == rr.position.x else -1.0
		var sy = 1.0 if corner.y == rr.position.y else -1.0
		draw_line(corner, corner + Vector2(l * sx, 0), c, 2)
		draw_line(corner, corner + Vector2(0, l * sy), c, 2)

func _draw_status(st: Dictionary, at: Vector2) -> void:
	var x = at.x
	for k in st:
		x -= 9
		draw_rect(Rect2(x, at.y, 8, 8), Data.STATUSES[k].color)
		draw_string(ThemeDB.fallback_font, Vector2(x + 1, at.y + 7), Data.STATUSES[k].name.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.BLACK)

func _draw_timeline() -> void:
	var tl = _timeline(8)
	var x = 6.0
	draw_string(ThemeDB.fallback_font, Vector2(x, 12), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.DIM)
	x += 30
	var sz = 22.0 if size.x > 420 else 18.0
	for i in tl.size():
		var u = tl[i]
		var r = Rect2(x, 3, sz, sz)
		var col = Color("3a5ac8") if u.side == "hero" else Color("a83a3a")
		draw_rect(r, col.darkened(0.4))
		draw_rect(r, UI.GOLD if i == 0 else col, false, 2.0 if i == 0 else 1.0)
		draw_texture_rect(u.tex, r.grow(-2), false)
		x += sz + 3
	var lt = log_text
	if lt != "" and size.x > 420:
		draw_string(ThemeDB.fallback_font, Vector2(x + 8, 18), lt, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 160, 11, Color("f2ead8"))
