extends Node
## Capture de la grotte de départ (planche « grotte vivante »).
## godot --path . res://tests/visual/grotte_capture.tscn
const OUT := "res://tests/visual/out/grotte/"
const MAIN = preload("res://main/main.tscn")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 600)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var main := MAIN.instantiate()
	vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.x = 14.0
	eng.z = -140.0
	GameState.sim_time = 30.0
	GameState.orb_active = true
	GameState.opening_stage = "awake"
	GameState.capsule_on = true
	GameState.opening_at = GameState.sim_time - 20.0
	(main.get_node("Hud") as CanvasLayer).visible = false
	var ts: TerrainState = world.terrain_state
	for x in range(-48, 49, 12):
		for z in range(-164, -99, 12):
			eng.x = x
			eng.z = z
			world.fog.refresh(ts)
	eng.x = 14.0
	eng.z = -150.0
	world.fog.refresh(ts)
	for v in [[Vector2(0, -166), 2], [Vector2(-4, -164), 3]]:
		world.camera.set_view(v[0], v[1])
		for i in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "grotte_px%d.png" % v[1]))
	get_tree().quit()
