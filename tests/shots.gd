extends Node
## Captures README screenshots (needs a real display, e.g. xvfb-run).
var main
var out := "user://"
func _ready() -> void:
	out = OS.get_environment("SHOTS") if OS.get_environment("SHOTS") != "" else "user://"
	_run.call_deferred()
func _f(n: int) -> void:
	for i in n: await get_tree().process_frame
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	var j: Image = img.duplicate()
	j.resize(900, int(900.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	j.save_jpg(out + "/" + name + ".jpg", 0.72)
	print("[shot] ", name)
func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _f(90)
	await _snap("title")
	Game.delete_save(); Game.new_game()
	main.goto("town", {"found": true}); await _f(5)
	var town = main.current
	for c in ["runeknight", "stormcaller", "thornwarden", "cleric"]: Game.recruit(c, true)
	town.close_sub(); await _f(30)
	await _snap("town")
	Game.mats = {"iron_ore": 30, "beast_hide": 10, "runestone": 10, "starsteel": 2, "frost_crystal": 5}
	Game.gold = 2400
	Game.add("runes", "fire_rune", 2); Game.add("runes", "frost_rune", 1)
	town.open_smith(); await _f(30)
	await _snap("forge")
	town.close_sub()
	main.goto("dungeon", {"floor": 2}); await _f(10)
	var d = main.current
	await _f(40)
	await _snap("dungeon")
	Game.heal_all()
	if not main.battle:
		main.start_battle(["wisp","golem","wolf"], false, d)
	await _f(150)
	await _snap("battle")
	get_tree().quit()
