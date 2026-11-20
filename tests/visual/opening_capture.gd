extends Node
## Captures de la séquence d'ouverture (sim/opening.gd), HUD et cadrage cinéma compris.
## godot --path . res://tests/visual/opening_capture.tscn
const OUT := "res://tests/visual/out/opening/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport
var main: Node
var sim: Simulation
var world: World


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _at(stage: String, t: float) -> void:
	GameState.opening_stage = stage
	GameState.opening_at = GameState.sim_time - t


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 600)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	main = MAIN.instantiate()
	_vp.add_child(main)
	sim = main.get_node("Simulation")
	world = main.get_node("World")
	sim.paused = true
	var eng: Unit = GameState.units[0]
	var st := world.terrain_state
	# 1-2 · Arrivée
	GameState.sim_time = 1.8
	world.camera.set_view(Opening.LAND + Vector2(0, -1), 3)
	eng.hidden = true
	await _shot("1_portail_ouvert")
	GameState.sim_time = 3.0
	eng.hidden = false
	await _shot("2_expulse")
	GameState.sim_time = 5.5
	await _shot("3_a_genoux")
	# 3 · Porte fermée, jeu du jour 1
	GameState.sim_time = 20.0
	_at("day1", 10.0)
	eng.x = 0.0
	eng.z = -84.0
	world.camera.set_view(Vector2(0, -80), 3)
	await _shot("4_porte")
	# 4 · Formation du bouclier (dans la grotte)
	eng.x = -4.0
	eng.z = -150.0
	GameState.orb_active = true
	GameState.shield_up = true
	GameState.shield_at = GameState.sim_time
	_at("shield_form", 0.4)
	world.camera.set_view(Vector2(0, -150), 3)
	await _shot("5_bouclier_forme")
	# 5 · Siège : intro puis jeu
	Opening.set_door(st, false)
	Opening.set_shield(st, true)
	GameState.shield_at = 0.0
	GameState.sim_time = 250.0
	_at("siege_intro", 1.6)
	world.camera.set_view(Opening.SIEGE_CAM, 2)
	await _shot("6_jour2_carton")
	_at("siege_intro", 3.0)
	await _shot("7_canons_arrivent")
	_at("siege", 10.3)
	await _shot("8_pilonnage")
	eng.x = 0.0
	eng.z = -66.0
	world.camera.set_view(Vector2(0, -70), 3)
	GameState.shield_line_said = false
	sim.tick(0.01)
	await _shot("9_sortie_bloquee")
	# 6 · Explosion
	world.camera.set_view(Opening.SIEGE_CAM, 2)
	eng.z = -100.0
	_at("blast", 3.5)
	await _shot("10_fissures")
	_at("blast", 5.0)
	await _shot("11_contraction")
	GameState.shield_up = false
	Opening.set_shield(st, false)
	world.open_breach()
	_at("blast", 5.8)
	await _shot("12_onde")
	_at("blast", 7.5)
	await _shot("13_fumee")
	# 7 · Remparts
	_at("waves", 3.0)
	eng.x = 0.0
	eng.z = -84.0
	world.camera.set_view(Vector2(0, -78), 3)
	await _shot("14_remparts")
	get_tree().quit()
