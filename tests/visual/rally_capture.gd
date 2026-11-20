extends Node
## Capture du drapeau de ralliement et de sa ligne dorée vers le temple sélectionné.
## godot --path . res://tests/visual/rally_capture.tscn
const OUT := "res://tests/visual/out/rally/"
const MAIN = preload("res://main/main.tscn")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_window().size = Vector2i(960, 600)
	var vp := get_viewport()
	load("res://sim/simulation.gd").play_opening = false
	var main := MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	sim.new_game(20261114)
	var t := Building.create(900, "medeina", 24.0, -120.0)
	t.complete = true
	t.finished_at = 0.0
	GameState.buildings.append(t)
	t.rally_point = Vector2(40.0, -126.0)
	GameState.hud_building = t
	main.get_node("Hud").dialogue.visible = false
	world.camera.set_view(Vector2(32, -126), 3)
	for i in 30:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + "rally.png"))
	get_tree().quit()
