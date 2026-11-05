extends Node
## Portrait layout check: captures each screen at phone size (xvfb-run, --resolution 390x844).
var main
var out := ""
func _ready() -> void:
	out = OS.get_environment("SHOTS")
	_run.call_deferred()
func _f(n: int) -> void:
	for i in n: await get_tree().process_frame
func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out + "/p_" + name + ".png")
	if name == "battle":
		img.save_jpg(out + "/mobile.jpg", 0.7)
func _run() -> void:
	get_window().size = Vector2i(390, 844)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _f(30); await _snap("title")
	Game.delete_save(); Game.new_game()
	main.goto("town", {"found": true}); await _f(10)
	await _snap("tavern")
	var town = main.current
	for c in ["runeknight", "stormcaller", "thornwarden", "cleric"]: Game.recruit(c, true)
	town.close_sub(); await _f(10); await _snap("town")
	Game.gold = 2400; Game.add("runes", "fire_rune", 2)
	town.open_smith(); await _f(10); await _snap("smith")
	var smith = town.sub_body.get_child(0)
	smith.tab = "weapons"; smith._rebuild(); await _f(10); await _snap("smith2")
	town.close_sub(); town.open_shop(); await _f(10); await _snap("shop")
	town.close_sub(); town.open_party(); await _f(10); await _snap("party")
	town.close_sub()
	main.goto("dungeon", {"floor": 1}); await _f(20); await _snap("dungeon")
	main.start_battle(["gel", "rat", "imp"], false, main.current); await _f(60); await _snap("battle")
	get_tree().quit()
