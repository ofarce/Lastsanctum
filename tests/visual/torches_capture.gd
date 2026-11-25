extends Node
## Captures des torches des couloirs du Temple (SanctumLayout._corridor_torches, TorchView) : une sur une paroi nord,
## une sur un rebord. godot --path . res://tests/visual/torches_capture.tscn -- --spot=N
const OUT := "res://tests/visual/out/torches/"
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
	var layout: Dictionary = Sanctum.data(ts)["layout"]
	var torches := {"n": [], "w": [], "e": []}
	for e: Dictionary in layout["props"]:
		if e.has("torch"):
			torches[e["torch"]].append(e)
	print("Torches : n=%d w=%d e=%d" % [torches["n"].size(), torches["w"].size(), torches["e"].size()])
	var only := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spot="):
			only = int(arg.trim_prefix("--spot="))
	var pick: Array = [torches["n"], torches["w"], torches["e"]][only % 3]
	if pick.is_empty():
		get_tree().quit()
		return
	var e: Dictionary = pick[(only / 3 * 7) % pick.size()]
	var c := Vector2(e["x"], e["z"])
	world.terrain_ops.reveal_gallery(c.x, c.y + 1.0)
	var at := c
	for o: Vector2 in [Vector2(6, 5), Vector2(-6, 5), Vector2(0, 7), Vector2(6, 0), Vector2(-6, 0), Vector2(0, -7)]:
		if ts.walkable(c.x + o.x, c.y + o.y):
			at = c + o
			break
	eng.x = at.x
	eng.z = at.y
	eng.tx = at.x
	eng.tz = at.y
	for i in 30:
		sim.tick(1.0 / 60.0)
	sim.paused = true
	world.camera.input_enabled = false
	world.camera.set_view(c + Vector2(0, -2), 5)
	world.fog.refresh(ts)
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	(main.get_node("Hud") as CanvasLayer).visible = false
	print("eng ", Vector2(eng.x, eng.z), " vis=", world.fog.visible_at(c), " gal=", ts.is_gallery(c.x, c.y + 1.0), " cam=", world.camera.cam)
	print("torche ", e["torch"], " ", c, " open=", ts.is_gallery_open(c.x, c.y))
	await _shot("%d_%s" % [only, e["torch"]])
	var tvs := get_tree().root.find_children("*", "Node2D", true, false).filter(func(n: Node) -> bool: return n is TorchView)
	for tv: Node in tvs.slice(0, 5):
		print("TorchView ", (tv as Node2D).get_parent().position, " vis=", (tv as Node2D).is_visible_in_tree())
	var nt := 0
	var near := []
	for ck: Vector2i in world.sanctum_view._props:
		for pe: Dictionary in world.sanctum_view._props[ck]:
			if pe.has("torch"):
				nt += 1
	for ck: Vector2i in world.sanctum_view._live:
		near.append(ck)
	print("props torches ", nt, " live ", near, " chunk torche ", Vector2i(floori(c.x / 32.0), floori(c.y / 32.0)))
	print("TorchView total ", tvs.size(), " ", world.sanctum_view._live.size())
	get_tree().quit()
