extends Node
## Capture du vrai rendu : orbite, relais et orientation, sans dépendre du temps réel.
const MAIN = preload("res://main/main.tscn")

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main = MAIN.instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	sim.new_game(20261114)
	var u: Unit = GameState.units[0]
	u.hidden = false
	u.unarmored = true
	u.x = -13
	u.z = -130
	u.tx = u.x
	u.tz = u.z
	GameState.portal_start = -100
	GameState.mining_seal = true
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(u.x, u.z), 4)
	world.finish_painting()
	DirAccess.make_dir_recursive_absolute("res://tests/visual/out/mining_seal")
	for t: float in [0.06, 0.30, 0.54, 1.25, 2.0]:
		GameState.sim_time = t
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var center := world.camera.project(u.x, 0, u.z)
		var img := viewport.get_texture().get_image().get_region(Rect2i(int(center.x) - 140, int(center.y) - 200, 280, 240))
		img.save_png("res://tests/visual/out/mining_seal/%.2f.png" % t)
	get_tree().quit()
