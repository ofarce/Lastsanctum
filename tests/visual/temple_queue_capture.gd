extends Node
## Capture de la file d'invocation au-dessus d'un temple : un esprit qui naît, trois en attente.
## godot --path . res://tests/visual/temple_queue_capture.tscn
const OUT := "res://tests/visual/out/temple_queue/"
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
	GameState.res["vie"] = 100.0
	for i in 4:
		sim.summon_adept(t)
	for i in roundi(4.0 * 60):
		sim.tick(1.0 / 60.0)
	sim.paused = true
	for u in GameState.units:
		u.hidden = u.arrival_end > 0.0
	main.get_node("Hud").dialogue.visible = false
	world.camera.set_view(Vector2(24, -128), 3)
	for i in 4:
		await RenderingServer.frame_post_draw
	# Sans alpha : la SubViewport garde celui des dessins semi-transparents (portraits d'esprits blanchis à l'affichage).
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(OUT + "file.png"))
	get_tree().quit()
