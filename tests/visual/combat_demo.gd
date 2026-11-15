extends Node
## Démonstration de combat en jeu réel (étape 8), fenêtrée : Ingénieur (rivets), lance-flammes (sillon),
## archer (charge), épée et bouclier (moulinet), balistes éveillées, contre rampants, cracheurs et brute.
## Lancement : godot --path . res://tests/visual/combat_demo.tscn
## Captures : tests/visual/out/etape8/demo_<n>.png ; fréquence d'images et bilan sur la sortie standard.
## `-- --profil` : fréquence d'images en combat stable (ennemis invulnérables), avec et sans surimpression,
## éclairage et HUD.

const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/etape8/"


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
	eng.x = -4.0
	eng.z = -104.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.orb_active = true
	GameState.orb_progress = Simulation.ORB_TIME
	sim.combat.activate_turrets()
	GameState.next_wave = 1e9
	var x := -2.0
	for k: String in ["flammes", "archer", "lame"]:
		var a := sim.spawn(Catalog.ADEPT[k]["name"], x, -98.0, k)
		a.hp = Catalog.ADEPT[k]["hp"]
		a.max_hp = a.hp
		x += 3.0
	for i in 9:
		var kind := "brute" if i == 4 else ("spitter" if i % 3 == 1 else "creep")
		sim.combat.spawn_enemy({"x": -4.0 + (i % 3) * 4.0, "kind": kind})
		var e: Enemy = GameState.enemies[-1]
		e.z = -82.0 + floorf(i / 3.0) * 4.0
	world.camera.set_view(Vector2(0, -90), 2)
	GameState.selected = [eng]
	if OS.get_cmdline_user_args().has("--profil"):
		# Combat stable : ennemis invulnérables, mêmes conditions pour chaque mesure.
		for e: Enemy in GameState.enemies:
			e.hp = 1e9
			e.max_hp = 1e9
		var hud: Hud = main.get_node("Hud")
		await get_tree().create_timer(2.0).timeout
		var cfgs := [["tout", true, true, true], ["sans surimpression", false, true, true], ["sans éclairage", true, false, true], ["sans HUD", true, true, false], ["rien", false, false, false]]
		for cfg: Array in cfgs + cfgs:
			world.overlay.visible = cfg[1]
			world.lighting.enabled = cfg[2]
			hud.visible = cfg[3]
			var f0 := Engine.get_frames_drawn()
			var s0 := Time.get_ticks_msec()
			await get_tree().create_timer(1.5).timeout
			print("PROFIL %s : %.1f im/s" % [cfg[0], (Engine.get_frames_drawn() - f0) * 1000.0 / (Time.get_ticks_msec() - s0)])
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--chrono"):
		# Images lentes (> 20 ms) des 3 premières secondes, avec les types d'effets vus pour la première fois.
		var seen := {}
		var last := Time.get_ticks_usec()
		var t_end := Time.get_ticks_msec() + 4500
		var t_go := Time.get_ticks_msec() + 1500
		sim.paused = true
		while Time.get_ticks_msec() < t_end:
			await get_tree().process_frame
			if sim.paused and Time.get_ticks_msec() >= t_go:
				sim.paused = false
				print("CHRONO reprise de la simulation")
			var now := Time.get_ticks_usec()
			var fresh := []
			for e: Dictionary in GameState.effects:
				if not seen.has(e["type"]):
					seen[e["type"]] = true
					fresh.append(e["type"])
			if (now - last) > 20000 or not fresh.is_empty():
				print("CHRONO %.2f s : image de %.1f ms %s" % [GameState.sim_time, (now - last) / 1000.0, fresh])
			last = now
		get_tree().quit()
		return
	# Fréquence d'images mesurée sur 2 s de combat, sans capture (l'écriture des PNG la fausserait).
	var frames := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(2.0).timeout
	var fps := (Engine.get_frames_drawn() - frames) * 1000.0 / (Time.get_ticks_msec() - t0)
	for n in 4:
		await get_tree().create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "demo_%d.png" % n))
	var lv := GameState.units.map(func(u: Unit) -> String: return "%s niv.%d %d PV" % [u.role, Catalog.lvl(u), int(u.hp)])
	print("im/s %.1f ; ennemis restants %d ; effets %d ; %s" % [fps, GameState.enemies.size(), GameState.effects.size(), ", ".join(lv)])
	get_tree().quit()
