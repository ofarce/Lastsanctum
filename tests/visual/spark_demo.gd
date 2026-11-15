extends Node
## Étincelle de réactivation de l'Ancre en jeu réel, fenêtrée : l'Ingénieur achève l'Énonciation, l'étincelle
## part de la sphère, la caméra la suit jusqu'aux balistes, qui s'arment à son arrivée.
## Lancement : godot --path . res://tests/visual/spark_demo.tscn
## Captures : tests/visual/out/etincelle/t_<temps>.png. `-- --profil` : fréquence d'images pendant le trajet et après.

const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/etincelle/"
const SHOTS := [0.45, 1.7, 3.2, 3.85, 4.4, 4.85, 5.9]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main := MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	GameState.portal_start = -100.0
	eng.x = Simulation.ORB_SPOT.x
	eng.z = Simulation.ORB_SPOT.y
	sim.order_orb(eng)
	GameState.orb_progress = Simulation.ORB_TIME - 0.3
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(0, -148), 2)
	while not GameState.orb_active:
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--profil"):
		# Fréquence d'images sans captures : pendant le trajet (0,7 → 4,75 s), puis après la séquence.
		while GameState.sim_time - GameState.orb_finished_at < AnchorSpark.T1:
			await get_tree().process_frame
		var g0 := Engine.get_frames_drawn()
		var m0 := Time.get_ticks_msec()
		while GameState.sim_time - GameState.orb_finished_at < AnchorSpark.T4:
			await get_tree().process_frame
		print("PROFIL étincelle : %.1f im/s" % ((Engine.get_frames_drawn() - g0) * 1000.0 / (Time.get_ticks_msec() - m0)))
		while GameState.sim_time - GameState.orb_finished_at < AnchorSpark.END + 0.2:
			await get_tree().process_frame
		g0 = Engine.get_frames_drawn()
		m0 = Time.get_ticks_msec()
		await get_tree().create_timer(3.0).timeout
		print("PROFIL après : %.1f im/s" % ((Engine.get_frames_drawn() - g0) * 1000.0 / (Time.get_ticks_msec() - m0)))
		get_tree().quit()
		return
	var f0 := Engine.get_frames_drawn()
	var s0 := Time.get_ticks_msec()
	for t: float in SHOTS:
		while GameState.sim_time - GameState.orb_finished_at < t:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + "t_%.2f.png" % t))
		print("capture %.2f s · caméra %s · balistes %s" % [t, world.camera.cam, [GameState.turrets[0]["complete"], GameState.turrets[1]["complete"]]])
	print("ÉTINCELLE : %.1f im/s" % ((Engine.get_frames_drawn() - f0) * 1000.0 / (Time.get_ticks_msec() - s0)))
	# Même vue, étincelle terminée : référence pour le coût de l'effet.
	while GameState.sim_time - GameState.orb_finished_at < AnchorSpark.END + 0.2:
		await get_tree().process_frame
	f0 = Engine.get_frames_drawn()
	s0 = Time.get_ticks_msec()
	await get_tree().create_timer(2.0).timeout
	print("APRÈS : %.1f im/s" % ((Engine.get_frames_drawn() - f0) * 1000.0 / (Time.get_ticks_msec() - s0)))
	get_tree().quit()
