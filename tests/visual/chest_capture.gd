extends Node
## Capture de la réserve du coffre antique : paroi intacte, réserve découverte, coffre en cours d'ouverture,
## coffre ouvert. godot --path . res://tests/visual/chest_capture.tscn
const OUT := "res://tests/visual/out/chest/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1200, 800)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.unarmored = true
	eng.x = 55.5
	eng.z = -146.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.mining_seal = true
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(64, -148), 3)
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("1_paroi")
	world.dig_cell(14, -37)
	world.dig_cell(15, -37)
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("2_reserve")
	eng.x = CaveShape.CHEST_SPOT.x
	eng.z = CaveShape.CHEST_SPOT.y
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.chest_opened_at = GameState.sim_time - 0.6
	await _shot("3_ouverture")
	GameState.chest_opened_at = GameState.sim_time - 5.0
	await _shot("4_ouvert")
	get_tree().quit()
