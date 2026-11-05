extends Node
## Persistent game state, hero/weapon math and save/load (user://).

const SAVE_PATH := "user://runebound_save.json"
const SETTINGS_PATH := "user://runebound_settings.json"
const MAX_LEVEL := 40

signal changed

var roster: Array = []        # hero dicts
var party: Array = []         # hero ids (max 4), battle order
var weapons: Array = []       # weapon dicts
var runes: Dictionary = {}    # rune_id -> count
var mats: Dictionary = {}     # material_id -> count
var items: Dictionary = {}    # item_id -> count
var gold := 0
var max_floor := 1            # highest floor unlocked
var cleared: Array = []       # floors whose boss was defeated (1-based)
var next_uid := 1
var stats := {"battles": 0, "kills": 0, "chests": 0, "forged": 0, "time": 0.0, "wins": 0}
var settings := {"sound": true, "music": true, "fast": false}
var started := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_setup_input()
	load_settings()

func _process(delta: float) -> void:
	if started:
		stats.time += delta

func _setup_input() -> void:
	var map = {
		"mv_up": [KEY_UP, KEY_W], "mv_down": [KEY_DOWN, KEY_S],
		"mv_left": [KEY_LEFT, KEY_A], "mv_right": [KEY_RIGHT, KEY_D],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in map[a]:
			var ev = InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

# ---------------------------------------------------------------- new game
func new_game() -> void:
	roster.clear(); party.clear(); weapons.clear()
	runes = {}; mats = {"iron_ore": 3, "beast_hide": 1}
	items = {"tonic": 4, "ether": 2, "ember_feather": 1, "clearwater": 1}
	gold = 150; max_floor = 1; cleared = []; next_uid = 1
	stats = {"battles": 0, "kills": 0, "chests": 0, "forged": 0, "time": 0.0, "wins": 0}
	started = true

func recruit(cls: String, free := false) -> Dictionary:
	var c: Dictionary = Data.CLASSES[cls]
	var h = {"id": next_uid, "cls": cls, "name": c.names[rng.randi() % c.names.size()], "lvl": 1, "xp": 0, "hp": 0, "mp": 0, "weapon": -1}
	next_uid += 1
	if not free:
		var lv = 1
		for o in roster:
			lv = max(lv, int(o.lvl))
		h.lvl = max(1, lv - 2)
	roster.append(h)
	var w = make_weapon(c.weapon, 0, 0)
	weapons.append(w)
	h.weapon = w.uid
	var s = hero_stats(h)
	h.hp = s.hp; h.mp = s.mp
	if party.size() < 4:
		party.append(h.id)
	changed.emit()
	return h

func recruit_cost() -> int:
	return 150 + 100 * max(0, roster.size() - 4)

func has_class(cls: String) -> bool:
	for h in roster:
		if h.cls == cls:
			return true
	return false

func hero(id) -> Dictionary:
	for h in roster:
		if int(h.id) == int(id):
			return h
	return {}

func party_heroes() -> Array:
	var out = []
	for id in party:
		var h = hero(id)
		if not h.is_empty():
			out.append(h)
	return out

func has_class_in_party(cls: String) -> bool:
	for h in party_heroes():
		if h.cls == cls:
			return true
	return false

# ---------------------------------------------------------------- stats
func xp_needed(lvl: int) -> int:
	return int(18 * pow(lvl, 1.55)) + 10

func hero_stats(h: Dictionary) -> Dictionary:
	var c: Dictionary = Data.CLASSES[h.cls]
	var lv = int(h.lvl) - 1
	var s = {}
	for k in ["hp", "mp", "atk", "mag", "def", "res", "spd"]:
		s[k] = float(c.base[k]) + float(c.grow[k]) * lv
	s.crit = float(c.base.crit)
	s.leech = 0.0
	s.brk = 0
	s.elem = "phys"
	var w = weapon(h.weapon)
	if not w.is_empty():
		var wt: Dictionary = Data.WEAPON_TYPES[w.type]
		var p = weapon_power(w)
		s.atk += p * wt.atk
		s.mag += p * wt.mag
		s.crit += wt.get("crit", 0)
		var pct_atk = 0.0
		var pct_mag = 0.0
		for a in w.affixes:
			match a.id:
				"atk_pct": pct_atk += a.val
				"mag_pct": pct_mag += a.val
				"spd": s.spd += a.val
				"crit": s.crit += a.val
				"hp": s.hp += a.val
				"leech": s.leech += a.val
				"breaker": s.brk += a.val
				"mp": s.mp += a.val
				"def": s.def += a.val
		for r in w.runes:
			var rd: Dictionary = Data.RUNES[r]
			if rd.elem != "" and s.elem == "phys":
				s.elem = rd.elem
			s[rd.stat] = s.get(rd.stat, 0.0) + rd.val
		s.atk *= 1.0 + pct_atk / 100.0
		s.mag *= 1.0 + pct_mag / 100.0
	for k in ["hp", "mp", "atk", "mag", "def", "res", "spd"]:
		s[k] = int(round(s[k]))
	return s

func gain_xp(h: Dictionary, amount: int) -> int:
	## returns number of levels gained
	var ups = 0
	h.xp = int(h.xp) + amount
	while int(h.lvl) < MAX_LEVEL and int(h.xp) >= xp_needed(int(h.lvl)):
		h.xp = int(h.xp) - xp_needed(int(h.lvl))
		h.lvl = int(h.lvl) + 1
		ups += 1
	if ups > 0:
		var s = hero_stats(h)
		h.hp = s.hp; h.mp = s.mp
	return ups

func heal_all() -> void:
	for h in roster:
		var s = hero_stats(h)
		h.hp = s.hp; h.mp = s.mp

func clamp_hero(h: Dictionary) -> void:
	var s = hero_stats(h)
	h.hp = clampi(int(h.hp), 0, s.hp)
	h.mp = clampi(int(h.mp), 0, s.mp)

func skills_for(h: Dictionary) -> Array:
	var out = []
	for sk in Data.CLASSES[h.cls].skills:
		if int(h.lvl) >= int(Data.SKILLS[sk].lvl):
			out.append(sk)
	return out

# ---------------------------------------------------------------- weapons
func weapon(uid) -> Dictionary:
	if uid == null:
		return {}
	for w in weapons:
		if int(w.uid) == int(uid):
			return w
	return {}

func weapon_power(w: Dictionary) -> float:
	return float(w.power) * (1.0 + 0.12 * int(w.plus))

func weapon_owner(uid) -> Dictionary:
	for h in roster:
		if int(h.weapon) == int(uid):
			return h
	return {}

func roll_rarity(q: int, tier: int) -> int:
	var r = rng.randf() * 100.0
	var bonus = q * 14.0 + tier * 3.0
	if r < 2.0 + bonus * 0.35: return 4
	if r < 8.0 + bonus * 0.7: return 3
	if r < 22.0 + bonus: return 2
	if r < 50.0 + bonus * 1.2: return 1
	return 0

func make_weapon(type: String, tier: int, rarity: int) -> Dictionary:
	tier = clampi(tier, 0, 4)
	var w = {"uid": next_uid, "type": type, "tier": tier, "rarity": rarity, "plus": 0,
		"power": 6 + tier * 9 + rarity * 2 + rng.randi_range(0, 2), "affixes": [], "sockets": 0, "runes": []}
	next_uid += 1
	var n_aff = [0, 1, 2, 3, 4][rarity]
	var pool: Array = Data.AFFIX_ORDER.duplicate()
	pool.shuffle()
	for i in n_aff:
		var id: String = pool[i]
		var a: Dictionary = Data.AFFIXES[id]
		var scale = 1.0 + tier * 0.45
		var v = int(round(rng.randf_range(a.min, a.max) * (scale if id in ["hp", "mp", "def"] else 1.0 + tier * 0.12)))
		if id == "breaker": v = 1 + (1 if rarity >= 4 else 0)
		w.affixes.append({"id": id, "val": max(1, v)})
	w.sockets = [0, 1, 1, 2, 3][rarity]
	if rarity == 0 and rng.randf() < 0.3:
		w.sockets = 1
	w.name = weapon_name(w)
	return w

func weapon_name(w: Dictionary) -> String:
	var base: String = Data.TIER_NAMES[int(w.tier)] + " " + Data.WEAPON_TYPES[w.type].name
	var n = base
	if w.affixes.size() >= 1:
		n = Data.AFFIXES[w.affixes[0].id].pre + " " + base
	if w.affixes.size() >= 2:
		n += " " + Data.AFFIXES[w.affixes[1].id].suf
	return n

func weapon_label(w: Dictionary) -> String:
	var t: String = w.name
	if int(w.plus) > 0:
		t += " +%d" % int(w.plus)
	return t

func weapon_lines(w: Dictionary) -> Array:
	var out = []
	var wt: Dictionary = Data.WEAPON_TYPES[w.type]
	var p = weapon_power(w)
	var line = "%s %s  ·  " % [Data.RARITY[int(w.rarity)], wt.name]
	if wt.atk >= 0.4: line += "ATK +%d " % int(round(p * wt.atk))
	if wt.mag >= 0.4: line += "MAG +%d" % int(round(p * wt.mag))
	out.append(line)
	for a in w.affixes:
		out.append("• " + (Data.AFFIXES[a.id].fmt % int(a.val)))
	var socks = "Sockets: "
	for i in int(w.sockets):
		socks += ("[" + Data.RUNES[w.runes[i]].name + "] ") if i < w.runes.size() else "[ empty ] "
	if int(w.sockets) == 0: socks += "none"
	out.append(socks)
	return out

func weapon_value(w: Dictionary) -> int:
	return int((10 + int(w.tier) * 25) * (1 + int(w.rarity) * 0.8) * (1 + int(w.plus) * 0.3))

func remove_weapon(uid) -> void:
	for i in weapons.size():
		if int(weapons[i].uid) == int(uid):
			weapons.remove_at(i)
			return

func upgrade_cost(w: Dictionary) -> Dictionary:
	var n = int(w.plus) + 1
	return {"gold": 40 * n * (1 + int(w.tier)), "mats": {"iron_ore": n + 1, "runestone": (n - 2) if n >= 3 else 0}}

func can_pay(cost: Dictionary) -> bool:
	if gold < int(cost.get("gold", 0)):
		return false
	for m in cost.get("mats", {}):
		if int(mats.get(m, 0)) < int(cost.mats[m]):
			return false
	return true

func pay(cost: Dictionary) -> void:
	gold -= int(cost.get("gold", 0))
	for m in cost.get("mats", {}):
		mats[m] = int(mats.get(m, 0)) - int(cost.mats[m])

func recipe_cost(r: Dictionary) -> Dictionary:
	var m = {}
	for k in r.mats:
		var key: String = k
		if k == "floor_mat":
			key = Data.FLOORS[clampi(max_floor - 1, 0, 4)].mat
		m[key] = int(m.get(key, 0)) + int(r.mats[k])
	return {"gold": r.gold, "mats": m}

func forge_tier(q: int) -> int:
	return clampi(max_floor - 1 + (1 if q >= 2 else 0), 0, 4)

func add(dict_name: String, id: String, n := 1) -> void:
	var d: Dictionary = get(dict_name)
	d[id] = int(d.get(id, 0)) + n

# ---------------------------------------------------------------- persistence
func to_dict() -> Dictionary:
	return {"v": 1, "roster": roster, "party": party, "weapons": weapons, "runes": runes, "mats": mats,
		"items": items, "gold": gold, "max_floor": max_floor, "cleared": cleared, "next_uid": next_uid, "stats": stats}

func save_game() -> bool:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY or not d.has("roster"):
		return false
	roster = []
	for h in d.roster:
		roster.append({"id": int(h.id), "cls": str(h.cls), "name": str(h.name), "lvl": int(h.lvl), "xp": int(h.xp),
			"hp": int(h.hp), "mp": int(h.mp), "weapon": int(h.weapon)})
	party = []
	for p in d.party:
		party.append(int(p))
	weapons = []
	for w in d.weapons:
		var aff = []
		for a in w.affixes:
			aff.append({"id": str(a.id), "val": int(a.val)})
		var rn = []
		for r in w.runes:
			rn.append(str(r))
		weapons.append({"uid": int(w.uid), "type": str(w.type), "tier": int(w.tier), "rarity": int(w.rarity), "plus": int(w.plus),
			"power": int(w.power), "affixes": aff, "sockets": int(w.sockets), "runes": rn, "name": str(w.name)})
	runes = _int_dict(d.get("runes", {}))
	mats = _int_dict(d.get("mats", {}))
	items = _int_dict(d.get("items", {}))
	gold = int(d.get("gold", 0))
	max_floor = int(d.get("max_floor", 1))
	cleared = []
	for c in d.get("cleared", []):
		cleared.append(int(c))
	next_uid = int(d.get("next_uid", 1000))
	var st: Dictionary = d.get("stats", {})
	for k in stats:
		stats[k] = float(st.get(k, 0)) if k == "time" else int(st.get(k, 0))
	started = true
	return true

func _int_dict(src) -> Dictionary:
	var out = {}
	if typeof(src) == TYPE_DICTIONARY:
		for k in src:
			out[str(k)] = int(src[k])
	return out

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func save_settings() -> void:
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
		f.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) == TYPE_DICTIONARY:
		for k in settings:
			if d.has(k):
				settings[k] = bool(d[k])

func fmt_time(t: float) -> String:
	var s = int(t)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
