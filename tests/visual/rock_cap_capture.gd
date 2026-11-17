extends Node
## Roche d'une case entourée de cases creusées : dessus texturé au-dessus de la paroi.
##   godot --path . res://tests/visual/rock_cap_capture.tscn
const MAIN = preload("res://main/main.tscn")
const CENTER := Vector2(-64, -154)


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 800)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var main = MAIN.instantiate()
	vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	GameState.sim_time = 30.0
	world.camera.input_enabled = false
	world.wind_scale = 0
	(main.get_node("Hud") as CanvasLayer).visible = false
	var c := Vector2i((CENTER / 4.0).floor())
	for j in range(c.y - 2, c.y + 3):
		for i in range(c.x - 2, c.x + 3):
			if Vector2i(i, j) != c and not (i == c.x + 2 and j <= c.y):
				world.dig_cell(i, j)
	GameState.effects.clear()
	world.fog.reset_exploration()
	GameState.units[0].x = CENTER.x
	GameState.units[0].z = CENTER.y + 10
	GameState.units[0].hidden = false
	world.fog.refresh(world.terrain_state)
	world.camera.set_view(CENTER, 4)
	world.finish_painting()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/visual/out/rock_cap.png"))
	get_tree().quit()
