extends Node
## Captures des ambiances de la montagne (bassin, champignons, lianes, racine, faune), galeries révélées.
## godot --path . res://tests/visual/ambience_capture.tscn -- --spot=N  (un point par lancement :
## le brouillard se recalcule mal quand on saute d'un bout à l'autre de la carte dans la même partie)
const OUT := "res://tests/visual/out/ambiances/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
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
	sim.paused = true
	GameState.sim_time = 30.0
	world.camera.input_enabled = false
	(main.get_node("Hud") as CanvasLayer).visible = false
	var ts: TerrainState = world.terrain_state
	var a: Dictionary = world.ambience
	print("Ambiances : %d bassins, %d touffes, %d lianes, %d racines, %d colonies, %d scarabées, %d salamandres" % [
		ts.pools.size(), a["mushrooms"].size(), a["vines"].size(), a["roots"].size(), a["bats"].size(), a["beetles"].size(), a["salamanders"].size()])
	var spots := []
	for p: Dictionary in ts.pools.slice(0, 2):
		spots.append(["bassin", p["center"]])
	for d: Dictionary in a["mushrooms"]:
		if d["lantern"]:
			spots.append(["champignons", Vector2(d["x"], d["z"])])
			break
	if not a["vines"].is_empty():
		spots.append(["lianes", Vector2(a["vines"][0]["x"], a["vines"][0]["z"])])
	if not a["roots"].is_empty():
		spots.append(["racine", Vector2(a["roots"][0]["x"], a["roots"][0]["z"])])
	if not a["beetles"].is_empty():
		spots.append(["scarabees", Vector2(a["beetles"][0]["x"], a["beetles"][0]["z"])])
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
		world.terrain_ops.reveal_galleries_near(c.x - 2, c.y - 2, c.x + 2, c.y + 2)
		world.fog.reset_exploration()
		# L'Ingénieur à côté du sujet (sur du sol), pas devant.
		var at := c + Vector2(0, 2)
		for o: Vector2 in [Vector2(9, 3), Vector2(-9, 3), Vector2(6, 6), Vector2(-6, 6), Vector2(0, 8)]:
			if ts.walkable(c.x + o.x, c.y + o.y):
				at = c + o
				break
		GameState.units[0].x = at.x
		GameState.units[0].z = at.y
		GameState.units[0].hidden = false
		world.camera.set_view(c + Vector2(0, 4), 3)
		world.finish_painting()
		world.fog.refresh(ts)
		print(s[0], " ", c, " ground=", ts.ground(c.x, c.y + 2), " vis=", world.fog.visible_at(c), " open=", ts.is_gallery_open(c.x, c.y))
		for k in 2:
			GameState.sim_time = 30.0 + k * 0.7
			await _shot("%d_%s_%d" % [n, s[0], k])
		n += 1
	get_tree().quit()
