extends Node
## Barre « Médaillon » des ennemis (planches/barres-vie-ennemis.html, piste A) : deux rangées d'ennemis à PV variés,
## mod Analyse porté (par une unité tenue hors champ) pour afficher les barres.
## godot --path . res://tests/visual/barres_vie_capture.tscn
const MAIN := preload("res://main/main.tscn")
const KINDS := ["soldier", "archer", "shield", "skeleton", "beast", "brute", "strazhar", "tick", "bat", "skeleton_bomb"]
const HP := [1.0, 0.62, 0.35, 0.8, 0.5, 0.9, 0.25, 0.7, 0.15, 0.45]


func _ready() -> void:
	var main := MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	main.get_node("Hud").hide()
	var eng: Unit = GameState.units[0]
	GameState.units.clear()
	eng.equipment["Module 1"] = "module_analyse"
	eng.x = 400.0
	eng.z = 400.0
	GameState.units.append(eng)
	GameState.portal_start = -100.0
	GameState.orb_active = true
	GameState.orb_finished_at = -20.0
	GameState.wave = 3
	GameState.next_wave = 1e9
	GameState.sim_time = 10.0
	world.finish_painting()
	world.camera.input_enabled = false
	var at := Vector2(0.15, -73.0)
	for i in KINDS.size():
		var e := Enemy.make(KINDS[i], at.x - 22.0 + (i % 5) * 11.0, at.y - 4.0 + (i / 5) * 8.0, 1.0)
		e.hp = e.max_hp * HP[i]
		GameState.enemies.append(e)
	for frame in 5:
		world._sync_enemies()
		await get_tree().process_frame
	world.camera.set_view(at + Vector2(0, 7), 4)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := "res://tests/visual/out/barres_vie.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/visual/out"))
	var err := get_viewport().get_texture().get_image().save_png(out)
	print("BARRES_VIE_CAPTURE ", err, " analyse=", Mods.analysis())
	get_tree().quit(0 if err == OK else 1)
