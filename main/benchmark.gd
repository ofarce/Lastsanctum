extends Node
## Banc d'essai (étape 12) : profilage du pire cas dans le jeu réel, synchronisation verticale coupée.
## PX = 1, éclairage, 3 galeries révélées (portails maléfiques éveillés), 15 adeptes et combattants,
## 40 ennemis, tous invulnérables (charge constante), balistes actives, HUD. Trois vues : entrée de la grotte (combat), jungle, salle.
## Lancement : jeu exporté ou éditeur avec `-- --banc [--frames=600 --vues=entree,jungle,salle --sans=… --profil-sim]`,
## Web avec `index.html?banc` ; ou directement godot --path . res://main/benchmark.tscn [-- options].
## Sortie : par vue, temps d'image moyen / p95 / max, temps processeur (process), temps GPU, appels de dessin,
## objets dessinés et im/s (lignes PERF), puis un résumé JSON (PERF_JSON) et BANC_FIN.
## Options de diagnostic : --sans=sim,hud,minimap,overlay,lighting,units,world,fx,decor (sous-systèmes
## coupés), --profil-sim (coût de chaque phase de la simulation), --compte, --textures.

const MAIN := preload("res://main/main.tscn")
const VIEWS := {"entree": Vector2(0, -78), "jungle": Vector2(0, 20), "salle": Vector2(0, -130)}

var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	print("PERF version : %s ; %s ; %s" % [Engine.get_version_info()["string"], OS.get_name(),
		"build exporté" if OS.has_feature("template") else "éditeur"])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var t0 := Time.get_ticks_msec()
	var main := MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	print("PERF chargement (new_game) : %d ms" % (Time.get_ticks_msec() - t0))
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	GameState.portal_start = -100.0
	eng.x = -4.0
	eng.z = -96.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.orb_active = true
	GameState.orb_progress = Simulation.ORB_TIME
	sim.combat.activate_turrets()
	GameState.next_wave = 1e9
	# 3 galeries : celles dont le portail est le plus proche de l'entrée.
	var st := sim.state()
	var ps := st.portals.duplicate()
	ps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a["x"], a["z"]).distance_to(Vector2(0, -80)) < Vector2(b["x"], b["z"]).distance_to(Vector2(0, -80)))
	t0 = Time.get_ticks_msec()
	for p: Dictionary in ps.slice(0, 3):
		world.terrain_ops.reveal_gallery(p["x"], p["z"])
	world.finish_painting()
	world.apply_view()
	print("PERF révélation de 3 galeries : %d ms (%d révélées)" % [Time.get_ticks_msec() - t0, st.found])
	# 15 alliés : 8 adeptes priants (2 par dieu) et 7 combattants.
	var roles := ["sigil", "sigil", "medeina", "medeina", "aether", "aether", "indra", "indra",
		"flammes", "flammes", "archer", "archer", "lame", "lame", "lame"]
	for i in roles.size():
		var k: String = roles[i]
		var a := sim.spawn(Catalog.ADEPT[k]["name"], -12.0 + (i % 8) * 3.0, -92.0 + floorf(i / 8.0) * 3.0, k)
		a.hp = Catalog.ADEPT[k]["hp"]
		a.max_hp = a.hp
	# Alliés invulnérables : le combat ne s'arrête pas (la défaite figerait la simulation en cours de mesure).
	for u: Unit in GameState.units:
		u.hp = 1e9
		u.max_hp = 1e9
	# 40 ennemis invulnérables (charge constante), au sud de l'entrée.
	for i in 40:
		var kind := "brute" if i % 10 == 0 else ("spitter" if i % 3 == 1 else "creep")
		var e := sim.combat.spawn_enemy({"x": -10.0 + (i % 8) * 3.0, "kind": kind})
		e.z = -60.0 + floorf(i / 8.0) * 3.0
		e.hp = 1e9
		e.max_hp = 1e9
	# Sous-systèmes coupés (répartition des coûts).
	var off: PackedStringArray = String(args.get("sans", "")).split(",", false)
	var hud: Hud = main.get_node("Hud")
	if off.has("sim"):
		sim.process_mode = Node.PROCESS_MODE_DISABLED
	if off.has("hud"):
		hud.visible = false
		hud.process_mode = Node.PROCESS_MODE_DISABLED
	if off.has("minimap"):
		hud.minimap.process_mode = Node.PROCESS_MODE_DISABLED
	if off.has("overlay"):
		world.overlay.visible = false
		world.overlay.process_mode = Node.PROCESS_MODE_DISABLED
	if off.has("lighting"):
		world.lighting.enabled = false
	if off.has("world"):
		world.set_process(false)
	if off.has("fx"):
		for n in world.find_children("*", "", true, false):
			if n is PortalSprite or n is DeityFx or n is EvilEmbers or n is OrbArcs or n is TurretView or n is BuildingView:
				n.process_mode = Node.PROCESS_MODE_DISABLED
	if off.has("decor"):
		for n in world.ysort.get_children():
			if not (n is UnitView or n is AdeptView):
				n.visible = false
	if args.has("textures"):
		var tex := {}
		for n in world.ysort.find_children("*", "Sprite2D", true, false):
			var t: Texture2D = (n as Sprite2D).texture
			var k: String = "planche" if t is AtlasTexture and (t as AtlasTexture).atlas.resource_path.ends_with("decor_atlas.png") \
				else (t.resource_path.get_base_dir() if t else "aucune")
			tex[k] = tex.get(k, 0) + 1
		print("PERF textures des sprites triés : ", tex)
	if args.has("compte"):
		var count := {}
		for n in world.find_children("*", "", true, false):
			var k: String = n.get_script().get_global_name() if n.get_script() else n.get_class()
			count[k] = count.get(k, 0) + 1
		print("PERF nœuds : ", count)
	sim.profiling = args.has("profil-sim")
	var frames := int(args.get("frames", "600"))
	var names: PackedStringArray = String(args.get("vues", "entree,jungle,salle")).split(",")
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var summary := {}
	for n in names:
		world.camera.set_view(VIEWS[n], 1)
		for i in 60:
			await get_tree().process_frame
		var dts := PackedFloat64Array()
		var cpu := 0.0
		var gpu := 0.0
		var dc := 0.0
		var obj := 0.0
		var last := Time.get_ticks_usec()
		for i in frames:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			dts.append((now - last) / 1000.0)
			last = now
			cpu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			# Le temps GPU n'est pas toujours disponible (valeurs aberrantes) : seules les valeurs plausibles comptent.
			var g := RenderingServer.viewport_get_measured_render_time_gpu(vp)
			gpu += g if g < 1000.0 else 0.0
			dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		var sorted := dts.duplicate()
		sorted.sort()
		var mean := 0.0
		for d in dts:
			mean += d
		mean /= dts.size()
		var r := {"fps": snappedf(1000.0 / mean, 0.1), "ms": snappedf(mean, 0.01), "p95": snappedf(sorted[int(sorted.size() * 0.95)], 0.01),
			"max": snappedf(sorted[-1], 0.01), "cpu_process_ms": snappedf(cpu / frames, 0.01), "gpu_ms": snappedf(gpu / frames, 0.01),
			"draw_calls": roundi(dc / frames), "objects": roundi(obj / frames), "enemies": GameState.enemies.size(),
			"units": GameState.units.filter(func(u: Unit) -> bool: return u.alive()).size(), "effects": GameState.effects.size()}
		summary[n] = r
		print("PERF %s : %.1f im/s (%.2f ms, p95 %.2f, max %.2f) ; process %.2f ms ; GPU %.2f ms ; %d appels de dessin ; %d objets" % [
			n, r["fps"], r["ms"], r["p95"], r["max"], r["cpu_process_ms"], r["gpu_ms"], r["draw_calls"], r["objects"]])
	if not sim.profile.is_empty():
		for k: String in sim.profile:
			var r: Array = sim.profile[k]
			print("PERF sim %s : %.2f ms en moyenne, max %.2f ms" % [k, r[0] / 1000.0 / r[2], r[1] / 1000.0])
	print("PERF_JSON " + JSON.stringify(summary))
	print("BANC_FIN")
	get_tree().quit()
