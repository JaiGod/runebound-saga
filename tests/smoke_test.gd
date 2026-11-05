extends Node
## Headless smoke test: drives the whole game loop with auto-battles.
## Run: godot --headless res://tests/SmokeTest.tscn

var main
var floors_to_play := 1

func _ready() -> void:
	floors_to_play = int(OS.get_environment("FLOORS")) if OS.get_environment("FLOORS") != "" else 1
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	Engine.time_scale = 12.0
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	print("[smoke] title ok: ", main.current_name)
	Game.delete_save()
	Game.new_game()
	main.goto("town", {"found": true})
	await _frames(3)
	var town = main.current
	for c in ["runeknight", "stormcaller", "shadeblade", "cleric"]:
		Game.recruit(c, true)
	town.close_sub()
	print("[smoke] party: ", Game.party.size(), " founding=", town.founding)
	for f in ["open_tavern", "open_smith", "open_shop", "open_party", "open_inn", "open_gate"]:
		town.call(f)
		await _frames(2)
		town.close_sub()
	# forge
	Game.mats = {"iron_ore": 30, "beast_hide": 10, "runestone": 10, "starsteel": 2, "frost_crystal": 5}
	Game.gold = 5000
	town.open_smith()
	await _frames(2)
	var smith = town.sub_body.get_child(0)
	for r in Data.RECIPES:
		smith._forge(r)
		await _frames(1)
	smith.tab = "weapons"; smith._rebuild()
	await _frames(2)
	town.close_sub()
	print("[smoke] weapons: ", Game.weapons.size())
	for w in Game.weapons: print("   ", Game.weapon_label(w), " | ", Game.weapon_lines(w))
	Game.add("runes", "fire_rune", 2)
	town.open_shop(); await _frames(2)
	var shop = town.sub_body.get_child(0)
	shop._buy("items", "tonic", 25); shop.tab = "sell"; shop._rebuild(); await _frames(2)
	town.close_sub()
	Game.gold = 300
	print("[smoke] save: ", Game.save_game(), " load: ", Game.load_game(), " roster=", Game.roster.size())
	Game.set_meta("auto", true)
	if OS.get_environment("SIM") != "":
		Game.weapons = Game.weapons.slice(0, 4)
		Game.mats = {}
	var tries = 0
	var fl = 1
	while fl <= floors_to_play and tries < 14:
		tries += 1
		_town_routine()
		main.goto("dungeon", {"floor": fl})
		await _frames(3)
		var ok = await _clear_floor(fl)
		var lv = []
		for h in Game.party_heroes(): lv.append(h.lvl)
		var ws = []
		for h in Game.party_heroes(): ws.append(Game.weapon_label(Game.weapon(h.weapon)))
		print("[smoke] floor ", fl, " boss cleared=", ok, " levels=", lv, " gold=", Game.gold, " weapons=", ws)
		if ok: fl += 1
	print("[smoke] DONE stats=", Game.stats)
	get_tree().quit()

func _clear_floor(fl: int) -> bool:
	var d = main.current
	var rng = RandomNumberGenerator.new()
	var steps = 0
	# visit foes then boss: walk path toward nearest alive foe using bfs
	while steps < 3000:
		steps += 1
		if main.battle:
			await _wait_battle()
			if main.current_name != "dungeon":
				return main.current_name == "ending"
			d = main.current
			if d.boss_dead:
				return true
			continue
		if d.busy:
			# a choice panel (portal) may be open - close it
			for c in d.get_children():
				if c is ColorRect: c.queue_free()
			d.busy = false
		var target = null
		var best = 1e9
		for f in d.foes:
			if not f.alive: continue
			var dist = (f.pos - d.player).length() + (50 if f.boss and _alive_normals(d) > 2 else 0)
			if dist < best: best = dist; target = f.pos
		if target == null: return false
		var bfs = d._bfs(target)
		var nxt = d.player
		for k in d.DIRS:
			var n = d.player + d.DIRS[k]
			if bfs.has(n) and bfs[n] < bfs.get(nxt, 1e9): nxt = n
		if nxt == d.player:
			d._try_step(d.DIRS.values()[rng.randi() % 4])
		else:
			d._try_step(nxt - d.player)
		await _frames(1)
	return false

func _town_routine() -> void:
	Game.heal_all()
	for h in Game.party_heroes():
		var ty = Data.CLASSES[h.cls].weapon
		for r in [Data.RECIPES[2], Data.RECIPES[1], Data.RECIPES[0]]:
			var c = Game.recipe_cost(r)
			if Game.can_pay(c) and Game.gold > c.gold + 100:
				Game.pay(c)
				var tier = Game.forge_tier(r.q)
				Game.weapons.append(Game.make_weapon(ty, tier, Game.roll_rarity(r.q, tier)))
				break
		var best = Game.weapon(h.weapon)
		for w in Game.weapons:
			if w.type == ty and Game.weapon_owner(w.uid).is_empty() and Game.weapon_power(w) > Game.weapon_power(best):
				best = w
		h.weapon = best.uid
		var uc = Game.upgrade_cost(best)
		while int(best.plus) < 5 and Game.can_pay(uc) and Game.gold > uc.gold + 80:
			Game.pay(uc); best.plus += 1; uc = Game.upgrade_cost(best)
	if Game.gold > 200 and int(Game.items.get("tonic", 0)) < 5:
		Game.gold -= 75; Game.add("items", "tonic", 3)
	Game.heal_all()

func _alive_normals(d) -> int:
	var n = 0
	for f in d.foes:
		if f.alive and not f.boss: n += 1
	return n

func _wait_battle() -> void:
	var b = main.battle
	var guard = 0
	while main.battle == b and guard < 20000:
		guard += 1
		await _frames(1)
		var rb = b.find_child("ResultButton", true, false) if is_instance_valid(b) else null
		if rb:
			var res = "win" if b._alive(b.enemies).is_empty() else "lose"
			var ko = 0
			var hp = 0.0
			for u in b.heroes:
				if not u.alive: ko += 1
				hp += float(u.hp) / u.mhp
			if b.boss or ko > 0 or res == "lose":
				print("    battle vs ", b.enemy_ids, " -> ", res, " turns=", b.turn_no, " KO=", ko, " hp%=", int(hp * 25))
			rb.emit_signal("pressed")
			await _frames(2)
			return
