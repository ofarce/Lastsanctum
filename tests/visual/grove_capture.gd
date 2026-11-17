extends Node
## Capture du bosquet pétrifié de la salle de départ et d'un bosquet de galerie (révélé), à l'usure 20 et 8.
## godot --path . res://tests/visual/grove_capture.tscn
const OUT := "res://tests/visual/out/groves/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 640)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	GameState.sim_time = 30.0
	world.camera.input_enabled = false
	(main.get_node("Hud") as CanvasLayer).visible = false
	var ts: TerrainState = world.terrain_state
	var n := 0
	for o: Vector2i in ts.wood_left:
		var c := Vector2(o * 4) + Vector2(4, 4)
		if not ts.ground(c.x, c.y):
			ts.reveal_galleries_near(c.x - 2, c.y - 2, c.x + 2, c.y + 2) if ts.has_method("reveal_galleries_near") else world.terrain_ops.reveal_galleries_near(c.x - 2, c.y - 2, c.x + 2, c.y + 2)
			world.fog.reset_exploration()
		GameState.units[0].x = c.x
		GameState.units[0].z = c.y + 7
		GameState.units[0].hidden = false
		world.camera.set_view(c, 3)
		world.finish_painting()
		world.fog.refresh(ts)
		await _shot("bosquet_%d" % n)
		ts.wood_left[o] = 8
		await _shot("bosquet_%d_use" % n)
		n += 1
		if n >= 2:
			break
	get_tree().quit()
