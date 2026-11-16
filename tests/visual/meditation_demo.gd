extends Node
## Méditation en lévitation : clic droit réel sur un temple avec l'Ingénieur sélectionné, puis captures
## de l'assise, de la lévitation, d'une lueur en vol et de l'éclat du temple (out/meditation/).
const OUT := "res://tests/visual/out/meditation/"
const MAIN = preload("res://main/main.tscn")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main = MAIN.instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.unarmored = true
	eng.x = -44
	eng.z = -104
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	var deity: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "medeina"
	var t := Building.create(GameState.buildings.size(), deity, -26.0, -118.0)
	t.complete = true
	t.progress = Catalog.BUILDINGS[deity]["time"]
	t.finished_at = -10.0
	GameState.buildings.append(t)
	GameState.selected = [eng]
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(-30, -112), 3)
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await get_tree().create_timer(0.4).timeout
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.position = world.camera.project(t.x, 1.0, t.z)
	click.global_position = click.position
	click.pressed = true
	viewport.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	viewport.push_input(click, true)
	print("Ordre : ", eng.job)
	while not (eng.job != null and eng.job.has("since")):
		await get_tree().process_frame
	var since: float = eng.job["since"]
	for at: float in [0.5, 1.9, 2.8, 3.05, 4.4]:
		while GameState.sim_time - since < at:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		var c := world.camera.project(eng.x, 0, eng.z)
		img = img.get_region(Rect2i(int(c.x) - 260, int(c.y) - 330, 520, 400))
		img.save_png(ProjectSettings.globalize_path(OUT + "%s_%.2f.png" % [deity, at]))
	print("Gains : ", eng.job["ticks"], " · Vie/Forge/… ", GameState.res)
	get_tree().quit()
