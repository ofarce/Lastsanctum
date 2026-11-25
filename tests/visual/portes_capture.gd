extends Node
## Captures des portes des tunnels (sim/cave_doors.gd, CaveDoorView) : bouches de la grotte et seuils des quartiers.
##   godot --path . res://tests/visual/portes_capture.tscn -- --spot=N [--open] [--broken]
## Spots : 0 bouche nord, 1 bouche est, 2-4 seuils A/B/C du Temple, 5-7 seuils des Salles oubliées,
## 10 arche et stèle du quartier C, 9 grandes portes du sud (partie lancée par Opening.start, porte ouverte en permanence).
const OUT := "res://tests/visual/out/portes/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
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
	var map_seed := 20261114
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			map_seed = int(arg.trim_prefix("--seed="))
	sim.new_game(map_seed)
	var spot0 := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spot="):
			spot0 = int(arg.trim_prefix("--spot="))
	if spot0 == 9:
		Opening.start(sim, Capsule.engineer())
		for i in 4:
			sim.tick(1.0 / 60.0)
		print("porte sud fermée : ", GameState.door_closed, " · praticable : ", sim.state().walkable(0.0, -78.0))
	GameState.opening_stage = ""
	GameState.in_capsule = false
	var eng := Capsule.engineer()
	eng.hidden = false
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	for i in 6:
		sim.tick(1.0 / 60.0)
	var ts: TerrainState = world.terrain_state
	var spot := 0
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--spot="):
			spot = int(arg.trim_prefix("--spot="))
	var c := Vector2(-22, -184)
	var into := Vector2.ZERO
	if spot == 9:
		c = Vector2(0, -84)
	elif spot == 10:
		for m: Dictionary in QuarterMarks.marks(ts):
			if m["kind"] == "arch" and m["quarter"] == "C":
				c = Vector2(m["x"], m["z"] - 3.0)
				print("arche C : ", m)
		into = Vector2(0, 1)
		GameState.quarter_lit["C"] = true
	elif spot == 1:
		c = Vector2(68, -110)
	elif spot >= 2:
		var ruins := CaveDoors.ruins(ts)
		if ruins.size() > spot - 2:
			c = ruins[spot - 2]["mid"]
			into = Vector2(ruins[spot - 2]["into"])
		print("ruines : ", ruins)
	if spot <= 1 and args.has("--broken"):
		GameState.cave_doors[spot]["hp"] = 0.0
		GameState.cave_doors[spot]["broken"] = true
	world.terrain_ops.reveal_gallery(c.x, c.y)
	var at := Vector2(-22, -181) if spot == 0 else Vector2(0, -92) if spot == 9 else c + Vector2(4, 9) if spot == 10 else (Vector2(62, -110) if spot == 1 else c + into * 10.0)
	if not args.has("--open"):
		at = Vector2(-22, -166) if spot == 0 else Vector2(0, -92) if spot == 9 else c + Vector2(4, 9) if spot == 10 else (Vector2(54, -110) if spot == 1 else c + into * 10.0)
	eng.x = at.x
	eng.z = at.y
	eng.tx = at.x
	eng.tz = at.y
	for i in 420:
		sim.tick(1.0 / 60.0)
	sim.paused = true
	world.camera.input_enabled = false
	world.camera.set_view(c + Vector2(0, 2), 4)
	world.fog.refresh(ts)
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	(main.get_node("Hud") as CanvasLayer).visible = false
	var tag := ("_s%d" % map_seed if map_seed != 20261114 else "") + ("_open" if args.has("--open") else "") + ("_broken" if args.has("--broken") else "")
	await _shot("%d%s" % [spot, tag])
	get_tree().quit()
