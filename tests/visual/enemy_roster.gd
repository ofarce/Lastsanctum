extends Node
## Rendu Godot de la fiche : neuf colonnes, marche / attaque / mort.
const MAIN := preload("res://main/main.tscn")


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
	GameState.sim_time = 10.0
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(0, -80), 2)
	for row in 3:
		var i := 0
		for kind: String in Catalog.ENEMY:
			var e := Enemy.make(kind, -32.0 + i * 8.0, -92.0 + row * 12.0, 1.0)
			if row == 2:
				e.hp = 0
				e.dead = true
				e.died_at = 8.0
				GameState.enemy_corpses.append(e)
			else:
				if row == 1:
					e.attack_started = 9.6
				GameState.enemies.append(e)
			i += 1
	for frame in 5:
		world._sync_enemies()
		for e: Enemy in GameState.enemies:
			if e.attack_started == -INF:
				e.x += 0.08
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := "res://tests/visual/out/enemy_roster.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/visual/out"))
	var err := get_viewport().get_texture().get_image().save_png(out)
	print("ENEMY_ROSTER_CAPTURE ", err, " ", out)
	get_tree().quit(0 if err == OK else 1)
