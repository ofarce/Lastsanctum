extends Node
## Captures Godot des scénarios de référence (tests/visual/reference/scenarios.json).
## Lancement (fenêtré : le rendu headless ne produit pas d'image) :
##   godot --path . res://tests/visual/capture.tscn -- --prefix=etape2
## Chaque scénario est rendu dans un SubViewport de la taille de la référence (1440×900), avec
## la même caméra, le même PX et le même temps de simulation, puis enregistré dans
## tests/visual/out/<préfixe>/<nom>.png. Comparer ensuite avec tests/visual/compare.py.

const SCENARIOS := "res://tests/visual/reference/scenarios.json"
const WORLD := preload("res://world/world.tscn")


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("perf"):
		await _perf(args)
		return
	if args.has("dig-profile"):
		await _dig_profile()
		return
	var prefix: String = args.get("prefix", "")
	var out_dir := "res://tests/visual/out/%s/" % (prefix if prefix else "all")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCENARIOS))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(config["viewport"][0], config["viewport"][1])
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world: World = WORLD.instantiate()
	viewport.add_child(world)
	world.camera.input_enabled = false

	# Même graine de galeries que les captures de référence (tools/baker/lib.js : GALLERY_SEED).
	var gallery_seed := int(config.get("gallery_seed", 0))
	world.reset_world(gallery_seed)
	var dug := false
	var done := 0
	for s: Dictionary in config["scenarios"]:
		if prefix and not String(s["name"]).begins_with(prefix):
			continue
		var disabled: Array = s.get("disable", [])
		GameState.sim_time = s["t"]
		var orb: Variant = s.get("orb", "")
		GameState.orb_active = orb is String and orb == "active"
		GameState.orb_progress = 8.0 if GameState.orb_active else (float(orb) * 8.0 if orb is float else 0.0)
		GameState.deity_active = {s["deity"]: true} if s.has("deity") else {}
		# Bâtiments posés directement (étape 7) : achevés, ou chantier à une progression donnée, sans Ingénieur.
		GameState.buildings.clear()
		for i in s.get("buildings", []).size():
			var bs: Dictionary = s["buildings"][i]
			var b := Building.create(i, bs["type"], bs["x"], bs["z"])
			var p: float = bs.get("progress", 1.0)
			b.progress = p * float(Catalog.BUILDINGS[b.type]["time"])
			b.complete = p >= 1.0
			GameState.buildings.append(b)
		# « text » neutralise ctx.fillText dans le prototype : seuls les textes disparaissent, pas les effets.
		world.overlay.show_text = not disabled.has("text")
		# Ennemis posés directement et balistes (étape 8).
		GameState.enemies.clear()
		for es: Dictionary in s.get("enemies", []):
			var e := Enemy.make(es["kind"], es["x"], es["z"], 1.0)
			e.hp = 20.0
			e.max_hp = 35.0
			GameState.enemies.append(e)
		# Héros et personnages posés directement (étape 9).
		GameState.units.clear()
		GameState.selected.clear()
		for i in s.get("units", []).size():
			var us: Dictionary = s["units"][i]
			var u := Unit.create(i, "U", us["x"], us["z"], us["role"])
			if us.has("hp"):
				u.hp = us["hp"]
			u.face = int(us.get("face", 0))
			if us.has("swing"):
				u.sw = int(us["swing"][0])
				u.sw_t0 = float(s["t"]) - float(us["swing"][1])
			if us.has("volley"):
				u.sh_t0 = float(s["t"]) - float(us["volley"])
			if us.get("selected", false):
				GameState.selected.append(u)
			GameState.units.append(u)
		# Effets posés directement (étape 9) : couleurs « #rrggbb », murs de feu (âge, durée restante).
		GameState.effects.clear()
		for es: Dictionary in s.get("effects", []):
			var e := es.duplicate()
			if e.has("color"):
				e["color"] = Color(e["color"])
			if e["type"] == "rivethit":
				e["tgt"] = null
			GameState.effects.append(e)
		GameState.fire_walls.clear()
		for ws: Dictionary in s.get("fire_walls", []):
			GameState.fire_walls.append({"x": ws["x"], "z": ws["z"], "dx": ws["dx"], "dz": ws["dz"], "len": ws["len"],
				"t0": float(s["t"]) - float(ws["age"]), "until": float(s["t"]) + float(ws["left"])})
		GameState.turrets.clear()
		if not disabled.has("turrets"):
			Combat.reset_turrets()
			for b in GameState.turrets:
				b["complete"] = s.get("turrets", "") == "active"
		world.wind_scale = 0.0 if disabled.has("wind") else 1.0
		world.lighting.enabled = not disabled.has("lighting")
		var cam := Vector2.ZERO
		if s.get("dig", false):
			# Scénario de creusement de référence (fixtures/dig_scenario.json), caméra sur la dernière case.
			if dug:
				world.reset_world(gallery_seed)
			var sc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/fixtures/dig_scenario.json"))
			var t0 := Time.get_ticks_usec()
			for c: Array in sc["cells"]:
				world.dig_cell(int(c[0]), int(c[1]))
			var queued := world.terrain_ops.painter.pending()
			var t1 := Time.get_ticks_usec()
			world.finish_painting()
			print("  peinture de la révélation : %d cases en file, %.1f ms au total (répartie sur ~%d images en jeu)" % [queued, (Time.get_ticks_usec() - t1) / 1000.0, ceili((Time.get_ticks_usec() - t1) / 8000.0)])
			print("  creusement de %d cases (révélation comprise) : %.1f ms" % [sc["cells"].size(), (Time.get_ticks_usec() - t0) / 1000.0])
			var last: Array = sc["cells"][sc["cells"].size() - 1]
			cam = Vector2(int(last[0]) * 4 + 2, int(last[1]) * 4 + 2)
			dug = true
		else:
			if dug:
				world.reset_world(gallery_seed)
				dug = false
			cam = Vector2(s["cam"]["x"], s["cam"]["z"])
		_set_visible(world, "arcs", not disabled.has("arcs"))
		_set_visible(world, "portals", not disabled.has("portals"))
		world.camera.set_view(cam, int(s["px"]))
		world.apply_view()
		# Personnages au repos (u._still ≥ 4) comme dans la référence.
		for i in (6 if s.has("enemies") or s.has("units") else 3):
			await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.save_png(out_dir + String(s["name"]) + ".png")
		print("capture ", s["name"])
		done += 1
	print("%d capture(s) dans %s" % [done, out_dir])
	get_tree().quit(0 if done > 0 else 1)


## Mesure de performance : `-- --perf --cam=x,z --px=1 --frames=300`. Rendu dans la fenêtre principale,
## vent actif ; affiche la fréquence moyenne et les monitors de rendu.
func _perf(args: Dictionary) -> void:
	var world: World = WORLD.instantiate()
	add_child(world)
	world.camera.input_enabled = false
	var c: PackedStringArray = String(args.get("cam", "0,10")).split(",")
	world.camera.set_view(Vector2(float(c[0]), float(c[1])), int(args.get("px", "1")))
	var frames := int(args.get("frames", "300"))
	for i in 30:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in frames:
		GameState.sim_time += 1.0 / 60.0
		await get_tree().process_frame
	var dt := (Time.get_ticks_usec() - t0) / 1e6
	print("PERF cam=%s px=%s : %.1f im/s moyens sur %d images ; appels de dessin %d ; objets dessinés %d" % [
		args.get("cam", "0,10"), args.get("px", "1"), frames / dt, frames,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	get_tree().quit(0)


## Profil du creusement : `-- --dig-profile`. Détaille le coût de chaque case du scénario de référence.
func _dig_profile() -> void:
	var world: World = WORLD.instantiate()
	add_child(world)
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	world.reset_world(20261114)
	print("PROFIL reset_world : %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	t0 = Time.get_ticks_usec()
	world.terrain_state.generate_galleries(20261114)
	print("PROFIL generate_galleries : %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var sc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/fixtures/dig_scenario.json"))
	var ops := world.terrain_ops
	for c: Array in sc["cells"]:
		var a := Time.get_ticks_usec()
		ops.painter.paint_dug_cell(int(c[0]), int(c[1]))
		var b := Time.get_ticks_usec()
		world.decor.remove_in_rect(-232, -336, 232, 72, func(_e: Dictionary) -> bool: return false)
		var c2 := Time.get_ticks_usec()
		world.terrain.flush()
		var d := Time.get_ticks_usec()
		world.dig_cell(int(c[0]), int(c[1]))
		var e := Time.get_ticks_usec()
		world.finish_painting()
		print("PROFIL case %s : peinture %.2f | parcours du décor %.2f | mise à jour texture %.2f | dig_cell complet %.2f ms" % [c, (b - a) / 1000.0, (c2 - b) / 1000.0, (d - c2) / 1000.0, (e - d) / 1000.0])
	get_tree().quit(0)


## Masque les éléments qu'une étape n'a pas encore à comparer (« disable » des scénarios).
func _set_visible(world: World, what: String, on: bool) -> void:
	for n in world.find_children("*", "", true, false):
		if what == "arcs" and n is OrbArcs:
			n.visible = on
		elif what == "portals" and (n is PortalSprite or n is DeityFx or n is EvilEmbers):
			n.visible = on
