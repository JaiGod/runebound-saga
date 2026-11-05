extends Control
## Root: screen switching, battles layered over dungeons, pause, toasts, screen shake, orientation.

const UI = preload("res://scripts/ui.gd")
const SCREENS := {
	"title": preload("res://scripts/Title.gd"),
	"town": preload("res://scripts/Town.gd"),
	"dungeon": preload("res://scripts/Dungeon.gd"),
	"ending": preload("res://scripts/Ending.gd"),
}
const BattleScript = preload("res://scripts/Battle.gd")

var root_layer: Control
var current: Control
var current_name := ""
var battle: Control
var overlay: CanvasLayer
var pause_panel: Control
var toast_box: VBoxContainer
var _shake := 0.0

func _ready() -> void:
	theme = UI.theme()
	get_tree().root.size_changed.connect(_on_window_resized)
	_on_window_resized()
	root_layer = Control.new()
	root_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_layer)
	overlay = CanvasLayer.new()
	overlay.layer = 10
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var oc = Control.new()
	oc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	oc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oc.theme = UI.theme()
	overlay.add_child(oc)
	toast_box = UI.vbox(3)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.position.y = 34
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	oc.add_child(toast_box)
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	goto("title")

func _on_window_resized() -> void:
	var ws = get_window().size
	if ws.y > ws.x * 1.1:
		get_window().content_scale_size = Vector2i(360, 640)
	else:
		get_window().content_scale_size = Vector2i(640, 360)

func goto(name: String, params := {}) -> void:
	if battle:
		battle.queue_free()
		battle = null
	if current:
		current.queue_free()
	get_tree().paused = false
	_close_pause()
	current = SCREENS[name].new()
	current.set("main", self)
	current.set("params", params)
	current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_name = name
	root_layer.add_child(current)

func start_battle(enemy_ids: Array, boss: bool, from: Node) -> void:
	Sfx.play("encounter")
	battle = BattleScript.new()
	battle.set("main", self)
	battle.set("enemy_ids", enemy_ids)
	battle.set("boss", boss)
	battle.set("source", from)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current.visible = false
	current.process_mode = Node.PROCESS_MODE_DISABLED
	root_layer.add_child(battle)

func end_battle(result: String) -> void:
	var src = battle.get("source") if battle else null
	if battle:
		battle.queue_free()
		battle = null
	if result == "lose":
		# Defeat: lose half your gold, wake up at the inn.
		Game.gold = int(Game.gold / 2)
		Game.heal_all()
		Game.save_game()
		goto("town", {"msg": "Your party was carried back to town... (lost half your gold)"})
		return
	current.visible = true
	current.process_mode = Node.PROCESS_MODE_INHERIT
	if src and src.has_method("on_battle_end"):
		src.on_battle_end(result)

# ------------------------------------------------------------------ juice
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	if _shake > 0.05:
		root_layer.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 9.0))
	elif root_layer.position != Vector2.ZERO:
		root_layer.position = Vector2.ZERO
		_shake = 0.0

func toast(text: String, col := UI.GOLD) -> void:
	var p = UI.panel(6)
	var l = UI.lbl(text, 12, col, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	if toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()

# ------------------------------------------------------------------ pause
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if pause_panel:
			_close_pause()
		elif current_name in ["town", "dungeon"] or battle:
			open_pause()
		get_viewport().set_input_as_handled()

func open_pause() -> void:
	if pause_panel:
		return
	get_tree().paused = true
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.theme = UI.theme()
	overlay.add_child(dim)
	pause_panel = dim
	var c = CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(c)
	var p = UI.panel(12)
	c.add_child(p)
	var v = UI.vbox(6)
	v.custom_minimum_size.x = 220
	p.add_child(v)
	v.add_child(UI.lbl("PAUSED", 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl("Play time " + Game.fmt_time(Game.stats.time), 11, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.btn("Resume", _close_pause))
	var sb = UI.btn("", func(): pass)
	var mb = UI.btn("", func(): pass)
	var upd = func():
		sb.text = "Sound: " + ("ON" if Game.settings.sound else "OFF")
		mb.text = "Music: " + ("ON" if Game.settings.music else "OFF")
	upd.call()
	sb.pressed.connect(func():
		Game.settings.sound = not Game.settings.sound
		Game.save_settings(); upd.call())
	mb.pressed.connect(func():
		Game.settings.music = not Game.settings.music
		Game.save_settings(); Sfx.refresh_music(); upd.call())
	v.add_child(sb)
	v.add_child(mb)
	v.add_child(UI.btn("How to Play", func(): show_help(overlay)))
	v.add_child(UI.btn("Quit to Title", func():
		if current_name == "town":
			Game.save_game()
		goto("title")))
	if battle == null and current_name == "dungeon":
		v.add_child(UI.lbl("Dungeon progress is kept until you leave.", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	UI.focus_first(v)

func _close_pause() -> void:
	if pause_panel:
		pause_panel.queue_free()
		pause_panel = null
	get_tree().paused = false

const HELP := """[b]GOAL[/b]  Recruit a party of four heroes, forge legendary weapons and conquer all 5 dungeon floors. Each floor ends with a boss.

[b]TOWN[/b]  Tavern: recruit heroes (6 classes) and choose your active four.  Blacksmith: forge weapons from materials, upgrade them +1 to +5, socket runes, salvage.  Shop: potions, runes, materials.  Inn: rest and save.

[b]DUNGEON[/b]  Move with Arrow keys / WASD, tap a tile or use the on-screen pad. Walk into monsters to fight. Chests hold loot, hidden traps hurt (a Shadeblade spots them). Defeat the boss to open the stairs.

[b]BATTLE[/b]  The timeline at the top shows who acts next; speed decides how often you act. Hit elemental WEAKNESSES to drain an enemy's break gauge: a BROKEN enemy loses its turn and takes +50% damage. Every hit fills the party COMBO gauge; when it is full, any hero can unleash a RUNE BURST.  Chain hits without letting enemies act for extra damage.

[b]CONTROLS[/b]  Mouse/touch: tap buttons and targets.  Keyboard: arrows to move/select, Enter/Space to confirm, Esc/P to pause or go back."""

func show_help(parent: Node) -> void:
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.theme = UI.theme()
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(dim)
	var m = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 14)
	dim.add_child(m)
	var p = UI.panel(10)
	m.add_child(p)
	var v = UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.lbl("HOW TO PLAY", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = HELP
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 11)
	r.add_theme_font_size_override("bold_font_size", 11)
	r.add_theme_color_override("default_color", UI.INK)
	v.add_child(r)
	var b = UI.btn("Close", dim.queue_free)
	v.add_child(b)
	b.grab_focus()
