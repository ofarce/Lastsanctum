extends Node
## Capture du premier boss : la Martyre de Byrsa sous son bouclier, adeptes repoussés au bord, Ingénieur en
## duel. godot --path . res://tests/visual/martyre_capture.tscn
const OUT := "res://tests/visual/out/martyre/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
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
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.unarmored = true
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	GameState.menace = Martyre.MENACE
	sim.tick(1.0 / 60.0)
	var c := Martyre.center()
	for i in 3:
		sim.spawn("Adepte", c.x - 10.0 + i * 8.0, c.y - 20.0, "indra")
	eng.x = c.x + 2.0
	eng.z = c.y - 12.0
	eng.tx = eng.x
	eng.tz = eng.z
	for i in 90:
		sim.tick(1.0 / 60.0)
	sim.paused = true
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.camera.set_view(c + Vector2(0, -Martyre.RADIUS + 4.0), 3)
	world.fog.refresh(sim.state())
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("1_bord_nord")
	world.camera.set_view(c + Vector2(0, Martyre.RADIUS - 6.0), 3)
	await _shot("2_bord_sud")
	world.camera.set_view(eng.pos(), 3)
	await _shot("3_duel")
	sim.paused = false
	for i in 240:
		sim.tick(1.0 / 60.0)
	sim.paused = true
	await _shot("4_duel_suite")
	print("PV Martyre ", GameState.martyre.hp if GameState.martyre else -1.0, " · Ingénieur ", eng.hp, " · état ", GameState.martyre_state)
	GameState.martyre.hp = 0.0
	sim.paused = false
	for i in 30:
		sim.tick(1.0 / 60.0)
	sim.paused = true
	await _shot("5_chute")
	get_tree().quit()
