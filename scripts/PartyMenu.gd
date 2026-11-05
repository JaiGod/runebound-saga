extends VBoxContainer
## Party: hero stats, skills and weapon equipping.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/Pix.gd")

var town
var sel := -1
var heroes_row: HFlowContainer
var det: VBoxContainer
var sc: ScrollContainer

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	heroes_row = HFlowContainer.new()
	heroes_row.add_theme_constant_override("h_separation", 4)
	heroes_row.add_theme_constant_override("v_separation", 4)
	add_child(heroes_row)
	det = UI.vbox(4)
	sc = UI.scroll(det)
	add_child(sc)
	if Game.hero(sel).is_empty() and Game.roster.size() > 0:
		sel = int(Game.party[0]) if Game.party.size() > 0 else int(Game.roster[0].id)
	_rebuild()

func _rebuild() -> void:
	UI.clear(heroes_row)
	for h in Game.roster:
		var active: bool = int(h.id) in Game.party
		var b = UI.btn("%s Lv%d%s" % [h.name, int(h.lvl), "" if active else " (bench)"], func(): sel = int(h.id); _rebuild(), 0, 30)
		b.icon = Pix.hero(h.cls)
		b.expand_icon = false
		b.add_theme_font_size_override("font_size", 10)
		if int(h.id) == sel:
			b.add_theme_stylebox_override("normal", UI.sb(Color("4a3a78"), UI.GOLD))
		heroes_row.add_child(b)
	UI.clear(det)
	var h = Game.hero(sel)
	if h.is_empty():
		return
	var c: Dictionary = Data.CLASSES[h.cls]
	var s = Game.hero_stats(h)
	var top = UI.hbox(8)
	det.add_child(top)
	top.add_child(UI.icon(Pix.hero(h.cls), 56))
	var info = UI.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(UI.lbl("%s — %s (%s)" % [h.name, c.name, c.role], 13, Data.ELEM_COLOR[c.elem]))
	info.add_child(UI.lbl("Level %d   XP %d / %d" % [int(h.lvl), int(h.xp), Game.xp_needed(int(h.lvl))], 10, UI.INK))
	info.add_child(UI.lbl("HP %d/%d   MP %d/%d" % [int(h.hp), s.hp, int(h.mp), s.mp], 10, UI.INK))
	info.add_child(UI.lbl("ATK %d  MAG %d  DEF %d  RES %d  SPD %d  CRIT %d%%" % [s.atk, s.mag, s.def, s.res, s.spd, int(s.crit)], 10, UI.GOLD))
	var extra = []
	if s.elem != "phys": extra.append("Attacks deal " + Data.ELEM_NAME[s.elem])
	if s.leech > 0: extra.append("Lifesteal %d%%" % int(s.leech))
	if s.brk > 0: extra.append("+%d break" % int(s.brk))
	if extra.size() > 0:
		info.add_child(UI.lbl(" · ".join(extra), 9, UI.GOOD))
	det.add_child(UI.lbl("Skills", 12, UI.GOLD))
	for sk in c.skills:
		var d: Dictionary = Data.SKILLS[sk]
		var unlocked = int(h.lvl) >= int(d.lvl)
		var el: String = d.get("elem", "")
		var t = "%s  (%d MP)  — %s" % [d.name, int(d.mp), d.desc]
		if not unlocked:
			t = "Lv%d: %s — %s" % [int(d.lvl), d.name, d.desc]
		det.add_child(UI.wrap(t, 10, (Data.ELEM_COLOR.get(el, UI.INK) if el != "" else UI.INK) if unlocked else Color("6a6080")))
	det.add_child(UI.lbl("Weapon", 12, UI.GOLD))
	var w = Game.weapon(h.weapon)
	if not w.is_empty():
		det.add_child(UI.lbl(Game.weapon_label(w), 11, Data.RARITY_COLOR[int(w.rarity)]))
		for line in Game.weapon_lines(w):
			det.add_child(UI.wrap(line, 9, UI.INK))
	det.add_child(UI.lbl("Equip a %s:" % Data.WEAPON_TYPES[c.weapon].name, 10, UI.DIM))
	var any = false
	for ww in Game.weapons:
		if ww.type != c.weapon or int(ww.uid) == int(h.weapon):
			continue
		any = true
		var owner = Game.weapon_owner(ww.uid)
		var b = UI.btn(Game.weapon_label(ww) + (" (from %s)" % owner.name if not owner.is_empty() else ""), func(): _equip(h, ww, owner), 0, 24)
		b.icon = Pix.weapon_icon(ww.type, int(ww.rarity), int(ww.tier))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Data.RARITY_COLOR[int(ww.rarity)])
		b.add_theme_font_size_override("font_size", 10)
		b.tooltip_text = "\n".join(Game.weapon_lines(ww))
		det.add_child(b)
	if not any:
		det.add_child(UI.lbl("No other weapons of this type. Forge one at the Blacksmith!", 9, UI.DIM))
	UI.focus_first(heroes_row)

func _equip(h: Dictionary, w: Dictionary, owner: Dictionary) -> void:
	var old: int = int(h.weapon)
	if not owner.is_empty():
		owner.weapon = old if Game.weapon(old).get("type", "") == Data.CLASSES[owner.cls].weapon else -1
		Game.clamp_hero(owner)
	h.weapon = int(w.uid)
	Game.clamp_hero(h)
	Sfx.play("buff")
	town.main.toast("%s equips %s." % [h.name, Game.weapon_label(w)], UI.GOOD)
	_rebuild()
