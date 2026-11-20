extends Node
## Captures du décor du Temple (world/sanctum) : une salle de chaque thème, une galerie de chaque famille et la
## paroi nord de la grotte de départ.
## godot --path . res://tests/visual/sanctum_capture.tscn -- --spot=N  (un point par lancement, comme les ambiances)
const OUT := "res://tests/visual/out/sanctum/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 640)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	for i in 30:
		sim.tick(1.0 / 60.0)
	GameState.selected = []
	GameState.incarnated = null
	sim.paused = true
	world.camera.input_enabled = false
	(main.get_node("Hud") as CanvasLayer).visible = false
	var ts: TerrainState = world.terrain_state
	var S := Sanctum.data(ts)
	var layout: Dictionary = S["layout"]
	var counts := {}
	for e: Dictionary in layout["props"]:
		counts[e["k"]] = int(counts.get(e["k"], 0)) + 1
	print("Sanctum : %d objets, %d braseros, %d salles" % [layout["props"].size(), layout["braziers"].size(), layout["rooms"].size()])
	print(counts)
	var spots := []
	var seen := {}
	for room: Dictionary in layout["rooms"]:
		if not seen.has(room["kind"]):
			seen[room["kind"]] = true
			spots.append([room["kind"], Vector2(room["x"], room["z"]), true])
	for k: String in ["drum", "brazier", "root_a", "banner", "quartz_m"]:
		for e: Dictionary in layout["props"]:
			if e["k"] == k and not e.get("start", false) and not e.has("room") and absf(float(e["x"])) > 90.0:
				spots.append([k, Vector2(e["x"], e["z"]), true])
				break
	for e: Dictionary in layout["props"]:
		if e.get("start", false) and e["k"] == "column":
			spots.append(["depart", Vector2(e["x"], float(e["z"]) + 4.0), false])
			break
	# Un brasero sur deux allumé, pour voir les deux états.
	for i in layout["braziers"].size():
		if i % 2 == 0:
			S["lit"][i] = true
	# --check : l'Ingénieur visite chaque salle et un brasero, la simulation tourne, l'état est affiché.
	if OS.get_cmdline_user_args().has("--check"):
		S["lit"].clear()
		sim.paused = false
		var res0: Dictionary = GameState.res.duplicate()
		var items0 := GameState.ground_items.size()
		eng.hp = eng.max_hp * 0.5
		eng.buff = 0.0
		for i in layout["rooms"].size():
			var room: Dictionary = layout["rooms"][i]
			world.terrain_ops.reveal_galleries_near(room["x"] - 2, room["z"] - 2, room["x"] + 2, room["z"] + 2)
			var f: Vector2 = room["focus"]
			eng.x = f.x + 1.5
			eng.z = f.y + 1.0
			eng.tx = eng.x
			eng.tz = eng.z
			for k in 40:
				sim.tick(1.0 / 60.0)
			print("%s : fait=%s prêt=%s PV=%.1f bonus=%.0f objets=+%d forge=+%d savoir=+%d marchable=%s" % [room["kind"], Sanctum.done(ts, i), Sanctum.ready(ts, i),
				eng.hp, eng.buff, GameState.ground_items.size() - items0, int(GameState.res["forge"] - res0["forge"]), int(GameState.res["savoir"] - res0["savoir"]), ts.walkable(eng.x, eng.z)])
		var b: Dictionary = layout["braziers"][0]
		eng.x = float(b["x"]) + 1.0
		eng.z = float(b["z"]) + 1.0
		for k in 40:
			sim.tick(1.0 / 60.0)
		print("brasero 0 allumé=%s, brasero 1 allumé=%s" % [Sanctum.lit(ts, 0), Sanctum.lit(ts, 1)])
		get_tree().quit()
		return
	var only := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spot="):
			only = int(arg.trim_prefix("--spot="))
	var n := 0
	for s: Array in spots:
		if only >= 0 and n != only:
			n += 1
			continue
		var c: Vector2 = s[1]
		if s[2]:
			world.terrain_ops.reveal_galleries_near(c.x - 2, c.y - 2, c.x + 2, c.y + 2)
			world.fog.reset_exploration()
			var at := c + Vector2(0, 3)
			for o: Vector2 in [Vector2(5, 3), Vector2(-5, 3), Vector2(0, 5), Vector2(3, 0), Vector2(-3, 0)]:
				if ts.walkable(c.x + o.x, c.y + o.y):
					at = c + o
					break
			eng.x = at.x
			eng.z = at.y
			eng.tx = at.x
			eng.tz = at.y
		else:
			eng.x = c.x + 3.0
			eng.z = c.y + 2.0
			eng.tx = eng.x
			eng.tz = eng.z
		world.camera.set_view(c + Vector2(0, 2), 3)
		world.finish_painting()
		world.fog.refresh(ts)
		print(s[0], " ", c, " open=", ts.is_gallery_open(c.x, c.y))
		await _shot("%d_%s" % [n, s[0]])
		n += 1
	get_tree().quit()
