extends Node
## Surcharge de l'Ancre en jeu réel, fenêtrée (sim/overload.gd) : anneau qui cède, colonne d'ombre, double
## nova, bouclier qui éclate, Ingénieur à genoux sans armure, puis le dialogue.
## Lancement : godot --path . res://tests/visual/overload_demo.tscn
## Captures : tests/visual/out/surcharge/<n>_<instant>.png (temps depuis le début ou depuis l'impact).

const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/surcharge/"
## [référence, décalage] : "t" depuis le début de l'événement, "h" depuis l'impact de la nova.
const SHOTS := [["t", 1.6], ["t", 2.55], ["t", 3.0], ["h", -0.1], ["h", 0.15], ["h", 0.4], ["h", 0.75], ["h", 1.6], ["h", 2.6], ["h", 6.0]]


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
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.orb_active = true
	GameState.orb_finished_at = GameState.sim_time - 20.0
	GameState.next_wave = 0.0
	world.camera.input_enabled = false
	world.camera.set_view(eng.pos(), 3)
	await get_tree().process_frame
	Overload.start(eng)
	var i := 0
	for s: Array in SHOTS:
		var base: float = GameState.overload_at if s[0] == "t" else GameState.overload_hit
		while GameState.sim_time - base < s[1]:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + "%d_%s%+.2f.png" % [i, s[0], s[1]]))
		print("capture %s%+.2f · PV %.0f · sans armure %s · à genoux %s" % [s[0], s[1], eng.hp, eng.unarmored, Overload.winded(eng)])
		i += 1
	# Après le dialogue, sans armure : creusement (lance-pitons noué au bras) puis agenouillement d'incantation.
	(main.get_node("Hud") as Hud).dialogue.close()
	GameState.selected = [eng]
	sim.order_adepts(Vector2(64, -138))
	var t0 := GameState.sim_time
	while GameState.sim_time - t0 < 20.0 and not (eng.working and eng.job != null):
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	world.camera.set_view(eng.pos(), 3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%d_creusement.png" % i))
	print("creusement : travail %s · job %s" % [eng.working, eng.job != null])
	eng.job = null
	eng.working = false
	eng.x = Simulation.ORB_SPOT.x
	eng.z = Simulation.ORB_SPOT.y
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.orb_active = false
	GameState.orb_owner = eng
	GameState.orb_progress = 1.0
	eng.orb_job = true
	world.camera.set_view(eng.pos(), 3)
	await get_tree().create_timer(0.3).timeout
	GameState.orb_progress = 1.0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%d_incantation.png" % (i + 1)))
	print("incantation : à genoux %s" % sim.kneeling(eng))
	get_tree().quit()
