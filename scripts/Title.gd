extends Control
## Title screen with an animated, code-drawn backdrop.

const UI = preload("res://scripts/ui.gd")
const Pix = preload("res://scripts/Pix.gd")

var main
var params := {}
var t := 0.0
var stars: Array = []
var motes: Array = []
var menu: VBoxContainer

func _ready() -> void:
	Sfx.music("title")
	var r = RandomNumberGenerator.new()
	r.seed = 7
	for i in 90:
		stars.append(Vector3(r.randf(), r.randf() * 0.65, r.randf() * TAU))
	for i in 24:
		motes.append({"p": Vector2(r.randf(), r.randf()), "v": r.randf_range(0.01, 0.04), "c": [Color("ffd36b"), Color("b07cff"), Color("7fd8ff")][i % 3]})
	var col = UI.vbox(6)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)
	var title = UI.lbl("RUNEBOUND", 40, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_shadow_color", Color("3a1a6a"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)
	var sub = UI.lbl("— S A G A —", 16, Color("c9b0ff"), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(sub)
	var heroes = UI.hbox(6)
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	for c in Data.CLASS_ORDER:
		heroes.add_child(UI.icon(Pix.hero(c), 40))
	col.add_child(heroes)
	var cc = CenterContainer.new()
	col.add_child(cc)
	menu = UI.vbox(5)
	menu.custom_minimum_size.x = 200
	cc.add_child(menu)
	_build_menu()
	var foot = UI.lbl("Made by Jaineil Rana (JaKing) · JaiGod", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(foot)

func _build_menu() -> void:
	UI.clear(menu)
	if Game.has_save():
		menu.add_child(UI.btn("Continue", func():
			if Game.load_game():
				main.goto("town")
			else:
				main.toast("Save file could not be read.", UI.BAD)))
	menu.add_child(UI.btn("New Game", func():
		if Game.has_save():
			_confirm_new()
		else:
			_start_new()))
	menu.add_child(UI.btn("How to Play", func(): main.show_help(self)))
	var snd = UI.btn("Sound: " + ("ON" if Game.settings.sound else "OFF"), func(): pass)
	snd.pressed.connect(func():
		Game.settings.sound = not Game.settings.sound
		Game.settings.music = Game.settings.sound
		Game.save_settings(); Sfx.refresh_music()
		snd.text = "Sound: " + ("ON" if Game.settings.sound else "OFF"))
	menu.add_child(snd)
	UI.focus_first(menu)

func _confirm_new() -> void:
	UI.clear(menu)
	menu.add_child(UI.wrap("Start over? Your current save will be replaced.", 12, UI.INK))
	menu.add_child(UI.btn("Yes, new adventure", _start_new))
	menu.add_child(UI.btn("Cancel", _build_menu))
	UI.focus_first(menu)

func _start_new() -> void:
	Game.new_game()
	main.goto("town", {"found": true})

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var s = size
	var bands = 14
	for i in bands:
		var c = Color("0b0716").lerp(Color("3a1f5c"), float(i) / bands)
		draw_rect(Rect2(0, s.y * i / bands, s.x, s.y / bands + 1), c)
	for st in stars:
		var a = 0.4 + 0.6 * absf(sin(t * 1.3 + st.z))
		draw_rect(Rect2(st.x * s.x, st.y * s.y, 2, 2), Color(1, 1, 1, a * 0.8))
	# moon
	draw_circle(Vector2(s.x * 0.82, s.y * 0.18), 22, Color("fff3d0"))
	draw_circle(Vector2(s.x * 0.82 + 8, s.y * 0.18 - 4), 20, Color("2a1846", 0.0))
	# mountains
	var m1 = PackedVector2Array([Vector2(0, s.y)])
	for i in 13:
		m1.append(Vector2(s.x * i / 12.0, s.y * (0.62 + 0.1 * sin(i * 1.7))))
	m1.append(Vector2(s.x, s.y))
	draw_colored_polygon(m1, Color("1e1236"))
	# spire / citadel
	var cx = s.x * 0.5
	var base = s.y * 0.78
	draw_rect(Rect2(cx - 30, base - 60, 60, 60), Color("140c26"))
	draw_rect(Rect2(cx - 10, base - 110, 20, 60), Color("140c26"))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 14, base - 110), Vector2(cx, base - 140), Vector2(cx + 14, base - 110)]), Color("140c26"))
	var glow = 0.5 + 0.5 * sin(t * 2.0)
	draw_circle(Vector2(cx, base - 95), 4, Color(1, 0.83, 0.42, 0.5 + glow * 0.5))
	for i in 3:
		draw_rect(Rect2(cx - 22 + i * 18, base - 40, 6, 8), Color(1, 0.8, 0.4, 0.6))
	var m2 = PackedVector2Array([Vector2(0, s.y)])
	for i in 9:
		m2.append(Vector2(s.x * i / 8.0, s.y * (0.8 + 0.06 * sin(i * 2.3 + 1.0))))
	m2.append(Vector2(s.x, s.y))
	draw_colored_polygon(m2, Color("0e0820"))
	for m in motes:
		var p: Vector2 = m.p
		var y = fposmod(p.y - t * m.v, 1.0)
		var x = p.x + 0.02 * sin(t + p.y * 10.0)
		var c: Color = m.c
		c.a = 0.7
		draw_rect(Rect2(x * s.x, y * s.y, 3, 3), c)
