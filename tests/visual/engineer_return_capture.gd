extends Node
## Mort et retour de l'Ingénieur (sim/engineer_return.gd) : chute, feu follet, attente des quatre bornes, souffle.
## godot --path . res://tests/visual/engineer_return_capture.tscn
const OUT := "res://tests/visual/out/retour/"
const MAIN = preload("res://main/main.tscn")
## Âge depuis la chute (s) ; au-delà de 20 s, l'Ingénieur est revenu.
const AGES := [0.04, 0.3, 0.5, 0.75, 1.6, 2.1, 2.45, 2.9, 3.2, 3.45, 3.7, 8.0, 14.0, 19.2, 19.6, 19.9, 20.05, 20.3, 20.7, 21.5]

var _vp: SubViewport


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 600)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	main.get_node("Hud").hide()
	GameState.opening_stage = ""
	GameState.orb_active = true
	GameState.capsule_on = true
	GameState.capsule_gift = OS.get_cmdline_user_args().find("nu") < 0
	GameState.sim_time = 100.0
	GameState.in_capsule = false
	world.finish_painting()
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.x = 11.0
	eng.z = -159.0
	eng.aim_dir = Vector2.RIGHT
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(5, -163), 4)
	for i in 12:
		await get_tree().process_frame
	eng.hp = 0.0
	eng.dead = true
	sim.engineer_fell(eng)
	var t0 := GameState.sim_time
	for a: float in AGES:
		GameState.sim_time = t0 + a
		if a >= Simulation.ENGINEER_RESPAWN and GameState.engineer_respawn_at != INF:
			GameState.sim_time = t0 + Simulation.ENGINEER_RESPAWN
			sim.engineer_respawn_tick()
			GameState.sim_time = t0 + a
		await _shot("%05.2f" % a)
	print("RETOUR_CAPTURE ok")
	get_tree().quit()
