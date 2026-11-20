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
	# Attaques à distance : Ingénieur immobile à l'est de la Martyre.
	var boss: Enemy = GameState.martyre
	eng.stance = "hold"
	eng.hp = eng.max_hp
	boss.x = c.x - 6.0
	boss.z = c.y - 10.0
	eng.x = boss.x + 12.0
	eng.z = boss.z
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.martyre_busy_until = -INF
	GameState.martyre_next = ["fissure"]
	GameState.martyre_next_at = GameState.sim_time
	world.camera.set_view(Vector2(boss.x + 6.0, boss.z - 3.0), 3)
	_run(sim, 0.4 + 6.0 / Martyre.FISSURE["speed"])
	await _shot("6_fissure")
	_run(sim, 6.0 / Martyre.FISSURE["speed"] + 0.12)
	await _shot("7_eruption")
	_run(sim, 1.4)
	eng.x = boss.x + 16.0
	eng.tx = eng.x
	GameState.martyre_busy_until = -INF
	GameState.martyre_next = ["rosace"]
	GameState.martyre_next_at = GameState.sim_time
	world.camera.set_view(Vector2(boss.x + 9.0, boss.z - 3.0), 3)
	_run(sim, Martyre.SEALS["place"] + Martyre.SEALS["charge"] * 0.6)
	await _shot("8_sceaux_charge")
	_run(sim, Martyre.SEALS["charge"] * 0.4 + 0.12)
	await _shot("9_sceaux_colonne")
	print("Après les attaques · Ingénieur ", eng.hp)
	GameState.martyre.hp = 0.0
	sim.paused = false
	for i in 30:
		sim.tick(1.0 / 60.0)
	sim.paused = true
	await _shot("5_chute")
	get_tree().quit()


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		sim.tick(1.0 / 60.0)
