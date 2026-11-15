extends Node
## Capture de la surbrillance intégrée au jeu, pilotée par le vrai pointeur.
const OUT := "res://tests/visual/out/mining_hover/"
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
	sim.paused = true
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.unarmored = true
	eng.x = 58
	eng.z = -138
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.research_done["mining_artifact"] = true
	GameState.selected = [eng]
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(52, -138), 2)
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "repos.png"))
	var motion := InputEventMouseMotion.new()
	motion.position = world.camera.project(66, 0, -138)
	motion.global_position = motion.position
	viewport.push_input(motion, true)
	get_window().mouse_entered.emit()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "survol.png"))
	var input: InputController = main.get_node("Input")
	print("Survol intégré : ", input._mining_hover.cell)
	get_tree().quit()
