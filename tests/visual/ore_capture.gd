extends Node
## Capture des minerais en paroi (filons et gisement), avec et sans les sprites de minerai.
## godot --path . res://tests/visual/ore_capture.tscn [-- --atlas=/chemin/atlas.png --name=essai]
## --atlas remplace l'atlas des minerais (PNG lu directement, sans import) pour juger une proposition en jeu.
const OUT := "res://tests/visual/out/ores/"
const MAIN = preload("res://main/main.tscn")
const OreView := preload("res://world/terrain/ore_view.gd")
const Blocks := preload("res://data/mineable_blocks.gd")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ores(n: Node, acc: Array) -> Array:
	if n.get_script() == OreView:
		acc.append(n)
	for c in n.get_children():
		_ores(c, acc)
	return acc


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
	world.wind_scale = 0
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var tag: String = args.get("name", "")
	var atlas: Texture2D = null
	if args.has("atlas"):
		atlas = ImageTexture.create_from_image(Image.load_from_file(args["atlas"]))
	var ts: TerrainState = world.terrain_state
	# Pour chaque minerai : un filon (paire) et un gisement inépuisable.
	var targets := {}
	for k: Vector2i in ts.block_types:
		var t: String = ts.block_types[k]
		if not Blocks.ORES.has(t) or k == TerrainState.VAULT_COPPER:
			continue
		var kind := "gisement" if ts.permanent_ores.has(k) else "filon"
		if kind == "filon" and ts.block_types.get(k + Vector2i.RIGHT, "") != t:
			continue
		if args.has("only") and args["only"] != t + "_" + kind:
			continue
		if not targets.has(t + "_" + kind) or args.has("last"):
			targets[t + "_" + kind] = k
	for name: String in targets:
		var k: Vector2i = targets[name]
		print(name, " ", k, " ", ts.block_types[k])
		world.camera.set_view(Vector2(k.x * 4 + 4, k.y * 4 + 2), 3)
		world.finish_painting()
		(main.get_node("Hud") as Hud).hide_notice()
		if args.has("nohud"):
			(main.get_node("Hud") as CanvasLayer).visible = false
		if atlas:
			for o: Node2D in _ores(main, []):
				o.atlas = atlas
		await _shot(name + tag)
		if tag:
			continue
		for o: Node2D in _ores(main, []):
			o.modulate.a = 0.0
		await _shot(name + "_nu")
		for o: Node2D in _ores(main, []):
			o.modulate.a = 1.0
	get_tree().quit()
