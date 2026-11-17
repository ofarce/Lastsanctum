extends Node
## Mur de roche entaillé par deux tranchées : le minerai se voit sur le dessus des cases de roche
## et sur le flanc (paroi face5) exposé au-dessus de chaque case creusée. Démonstration du rendu,
## pas la répartition réelle des filons.
##   godot --path . res://tests/visual/ore_face_capture.tscn -- --sets=paillettes,filets
## « jeu » (par défaut) : rendu du jeu tel quel (dessus nodules.png, flancs posés par World._attach_ore_face).
## Piste <k> : atlas planches/assets/minerais-v4/atlas-<k>.png (dessus) et flancs-<k>.png à la place.
## « actuel » : atlas du jeu sur le dessus, flancs masqués.
const OUT := "res://tests/visual/out/ores/"
const DIR := "res://planches/assets/minerais-v4/"
const MAIN = preload("res://main/main.tscn")
const OreView := preload("res://world/terrain/ore_view.gd")
const Blocks := preload("res://data/mineable_blocks.gd")
const CENTER := Vector2(-64, -154)

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.3).timeout
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
	rng.seed = 11
	var c := Vector2i((CENTER / 4.0).floor())
	# Deux tranchées horizontales dans la roche pleine.
	var trenches := [[c.y - 1, c.x - 7, c.x + 3], [c.y + 3, c.x - 7, c.x + 2]]
	var dug := {}
	for t: Array in trenches:
		for i in range(t[1], t[2] + 1):
			if _solid(ts, Vector2i(i, t[0])):
				dug[Vector2i(i, t[0])] = true
	# Minerais : rangée au-dessus de chaque tranchée (flancs exposés) + quelques filons sur le dessus.
	var ores := {}
	var plan := ["copper", "iron", "quartz", "gold"]
	var n := 0
	for t: Array in trenches:
		var i: int = t[1] + 1
		while i < t[2]:
			var a := Vector2i(i, t[0] - 1)
			if _solid(ts, a) and _solid(ts, a + Vector2i.RIGHT) and not dug.has(a):
				var ore: String = plan[n % 4]
				n += 1
				ores[a] = ore
				ores[a + Vector2i.RIGHT] = ore
				if n % 3 == 0:
					ts.permanent_ores[a] = true
				i += 3
			else:
				i += 1
	for j in range(c.y - 9, c.y + 6):
		var i := c.x - 18
		while i < c.x + 4:
			var a := Vector2i(i, j)
			var b := a + Vector2i.RIGHT
			var free := not dug.has(a) and not dug.has(b) and not ores.has(a) and not ores.has(b) \
					and not dug.has(a + Vector2i.DOWN) and not dug.has(b + Vector2i.DOWN)
			if free and _solid(ts, a) and _solid(ts, b) and rng.randf() < 0.16:
				var ore: String = plan[rng.randi_range(0, 3)]
				ores[a] = ore
				ores[b] = ore
				if rng.randf() < 0.3:
					ts.permanent_ores[a] = true
				i += 4
			else:
				i += 1
	for k: Vector2i in ores:
		ts.block_types[k] = ores[k]
		# Démonstration : on retire les rochers de décor posés sur les cases de minerai.
		world.decor.remove_in_rect(k.x * 4.0, k.y * 4.0 - 4.0, k.x * 4.0 + 4.0, k.y * 4.0 + 4.0, func(e: Dictionary) -> bool:
			return not DecorRegistry.is_fixed(e) and not String(e.get("s", "")).begins_with("face5_"))
	for k: Vector2i in dug:
		world.dig_cell(k.x, k.y)
	var views: Array = []
	for k: Vector2i in ores:
		var v := OreView.new()
		v.setup(ts, k)
		world.ysort.add_child(v)
		views.append(v)
	# Calques de flanc posés par le jeu (World._attach_ore_face) sur les parois des cases de minerai.
	var overlays: Array = []
	for e: Dictionary in world.decor.entries():
		if not String(e.get("s", "")).begins_with("face5_") or not e.has("node"):
			continue
		var face: Node = (e["node"] as Node).get_child(0)
		if face.has_node("OreFace"):
			var cell := Vector2i(floori(e["bx"] / 4.0), floori(e["bz"] / 4.0) - 1)
			overlays.append({"sprite": face.get_node("OreFace"), "ore": ores.get(cell, ts.block_types[cell]),
					"row": 1 if ts.permanent_ores.has(cell) else 0})
	print("minerais : %d cases, %d flancs" % [ores.size(), overlays.size()])
	GameState.effects.clear()  # retire les marques de creusage (simulation en pause)
	world.camera.set_view(CENTER, 3)
	world.finish_painting()
	for key: String in String(args.get("sets", "jeu")).split(","):
		if key == "jeu":  # rendu du jeu tel quel
			await _shot("flanc_jeu")
			continue
		var atlas: Texture2D = OreView.NODULES
		var flancs: Image = null
		if key != "actuel":
			atlas = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(DIR + "atlas-%s.png" % key)))
			flancs = Image.load_from_file(ProjectSettings.globalize_path(DIR + "flancs-%s.png" % key))
		for v in world.ysort.get_children():
			if v.get_script() == OreView:
				v.atlas = atlas
		for o: Dictionary in overlays:
			var s: Sprite2D = o["sprite"]
			if flancs == null:
				s.visible = false
				continue
			var col := Blocks.ORES.find(o["ore"])
			s.visible = true
			s.region_enabled = false
			s.texture = ImageTexture.create_from_image(flancs.get_region(Rect2i(col * 32, o["row"] * 49, 32, 49)))
		await _shot("flanc_%s" % key)
	get_tree().quit()


func _solid(ts: TerrainState, k: Vector2i) -> bool:
	for p: Vector2 in [Vector2(0.5, 0.5), Vector2(2, 2), Vector2(3.5, 3.5), Vector2(0.5, 3.5), Vector2(3.5, 0.5)]:
		if ts.walkable(k.x * 4 + p.x, k.y * 4 + p.y) or ts.is_gallery(k.x * 4 + p.x, k.y * 4 + p.y):
			return false
	return not ts.block_types.has(k)
