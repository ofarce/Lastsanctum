extends Node
## Mort « Souffle » (entities/unit/ash_death.gd) : quatre ennemis par ligne, une ligne par âge de la mort.
## godot --path . res://tests/visual/mort_capture.tscn
const MAIN := preload("res://main/main.tscn")
const KINDS := ["beast", "soldier", "brute", "skeleton"]
const AGES := [0.05, 0.2, 0.7, 2.0]


func _ready() -> void:
	var main := MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	main.get_node("Hud").hide()
	GameState.units.clear()
	GameState.portal_start = -100.0
	GameState.orb_active = true
	GameState.orb_finished_at = -20.0
	GameState.wave = 3
	GameState.next_wave = 1e9
	GameState.sim_time = 10.0
	world.finish_painting()
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(0, -74), 3)
	# La caméra peut rester verrouillée sur la capsule : les ennemis se placent là où elle regarde.
	var at := Vector2(0.15, -73.0)
	for row in AGES.size():
		for i in KINDS.size():
			var e := Enemy.make(KINDS[i], at.x - 19.0 + i * 13.0, at.y - 9.0 + row * 5.5, 1.0)
			e.face = -1 if i == 3 else 1
			e.hp = 0
			e.dead = true
			e.died_at = GameState.sim_time - float(AGES[row])
			GameState.enemy_corpses.append(e)
	for frame in 5:
		world._sync_enemies()
		await get_tree().process_frame
	world.camera.set_view(at, 3)
	await get_tree().process_frame
	print("CAM ", world.camera.cam, " ", world.camera.px)
	await RenderingServer.frame_post_draw
	var out := "res://tests/visual/out/mort/souffle.png"
	var err := get_viewport().get_texture().get_image().save_png(out)
	print("MORT_CAPTURE ", err, " ", out)
	get_tree().quit(0 if err == OK else 1)
