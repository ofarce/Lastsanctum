extends Node
## Mur de roche garni de minerais (démonstration du rendu, pas la répartition réelle du jeu).
## godot --path . res://tests/visual/ore_wall_capture.tscn [-- --atlas=/chemin/atlas.png --name=essai]
## Les cases de roche pleine autour de la paroi ouest de la salle reçoivent des filons par paires
## (cuivre, fer, quartz, or) et quelques gisements inépuisables ; capture au zoom 3 et au zoom 2.
const OUT := "res://tests/visual/out/ores/"
const MAIN = preload("res://main/main.tscn")
const OreView := preload("res://world/terrain/ore_view.gd")
const Blocks := preload("res://data/mineable_blocks.gd")
const CENTER := Vector2(-60, -150)

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 800)
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
	(main.get_node("Hud") as CanvasLayer).visible = false
	var ts: TerrainState = world.terrain_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var added: Array[Vector2i] = []
	var c := Vector2i((CENTER / 4.0).floor())
	for j in range(c.y - 10, c.y + 11):
		var i := c.x - 20
		while i < c.x + 20:
			var a := Vector2i(i, j)
			var b := a + Vector2i.RIGHT
			if _solid(ts, a) and _solid(ts, b) and not ts.block_types.has(a) and not ts.block_types.has(b) \
					and rng.randf() < 0.42:
				var ore: String = Blocks.ORES[rng.randi_range(0, 3)]
				ts.block_types[a] = ore
				ts.block_types[b] = ore
				if rng.randf() < 0.25:
					ts.permanent_ores[a] = true
				added.append_array([a, b])
				i += 3
			else:
				i += 1
	var atlas: Texture2D = null
	if args.has("atlas"):
		atlas = ImageTexture.create_from_image(Image.load_from_file(args["atlas"]))
	for k in added:
		var v := OreView.new()
		v.setup(ts, k)
		if atlas:
			v.atlas = atlas
		world.ysort.add_child(v)
	if atlas:
		for n in world.ysort.get_children():
			if n.get_script() == OreView:
				n.atlas = atlas
	print("minerais ajoutés : ", added.size())
	var tag: String = args.get("name", "")
	for px in [3, 2]:
		world.camera.set_view(CENTER, px)
		world.finish_painting()
		await _shot("mur_z%d%s" % [px, tag])
	get_tree().quit()


func _solid(ts: TerrainState, k: Vector2i) -> bool:
	for p: Vector2 in [Vector2(0.5, 0.5), Vector2(2, 2), Vector2(3.5, 3.5), Vector2(0.5, 3.5), Vector2(3.5, 0.5)]:
		if ts.walkable(k.x * 4 + p.x, k.y * 4 + p.y) or ts.is_gallery(k.x * 4 + p.x, k.y * 4 + p.y):
			return false
	return true
