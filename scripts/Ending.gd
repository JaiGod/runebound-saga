extends Control
## Victory ending after the Umbral Regent falls.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/Pix.gd")

var main
var params := {}
var t := 0.0
var sparks: Array = []

func _ready() -> void:
	Sfx.music("town")
	Sfx.play("victory")
	var col = UI.vbox(6)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)
	col.add_child(UI.lbl("THE DEPTHS ARE SEALED", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var msg = UI.wrap("The Umbral Regent shatters into a thousand dim runes. Light returns to Emberhold, and your company's names are carved into the town's great stone.", 12, UI.INK)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size.x = 320
	var cc = CenterContainer.new()
	cc.add_child(msg)
	col.add_child(cc)
	var row = UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for h in Game.party_heroes():
		var v = UI.vbox(0)
		v.add_child(UI.icon(Pix.hero(h.cls), 44))
		v.add_child(UI.lbl("%s Lv%d" % [h.name, int(h.lvl)], 10, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(v)
	col.add_child(row)
	var st: Dictionary = Game.stats
	col.add_child(UI.lbl("Time %s · Battles %d · Monsters %d · Weapons forged %d" % [Game.fmt_time(st.time), st.wins, st.kills, st.forged], 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var bc = CenterContainer.new()
	col.add_child(bc)
	var bv = UI.vbox(5)
	bv.custom_minimum_size.x = 220
	bc.add_child(bv)
	bv.add_child(UI.btn("Keep adventuring (bosses grow stronger)", func(): main.goto("town")))
	bv.add_child(UI.btn("Title screen", func(): main.goto("title")))
	UI.focus_first(bv)

func _process(delta: float) -> void:
	t += delta
	if randf() < 0.5:
		sparks.append({"p": Vector2(randf() * size.x, size.y + 4), "v": Vector2(randf_range(-20, 20), randf_range(-140, -60)), "c": [UI.GOLD, Color("c47bff"), Color("7fd8ff")][randi() % 3], "l": 3.0})
	for s in sparks:
		s.p += s.v * delta
		s.l -= delta
	sparks = sparks.filter(func(s): return s.l > 0)
	queue_redraw()

func _draw() -> void:
	for i in 12:
		draw_rect(Rect2(0, size.y * i / 12.0, size.x, size.y / 12.0 + 1), Color("1a1036").lerp(Color("c8783a"), float(i) / 14.0))
	for s in sparks:
		draw_rect(Rect2(s.p, Vector2(3, 3)), s.c)
