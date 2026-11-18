extends SceneTree
## Aperçu de la carte générée : godot --headless --path . -s res://tools/worldgen/preview.gd -- <graine> <sortie.png>
## Roche par biome (teinte), galeries, zone d'origine (cadre), filons, minerai en paroi, bosquets, bassins.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := int(args[0]) if args.size() > 0 else 20261114
	var out := args[1] if args.size() > 1 else "user://worldgen_preview.png"
	var st := TerrainState.new()
	st.generate_galleries(map_seed)
	var w := TerrainState.GAL_W
	var h := TerrainState.GAL_H
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rock := [Color("#3a342d"), Color("#2b3340")]
	for j in h:
		var z := j + CaveShape.WORLD_Z0 + 0.5
		for i in w:
			var x := i + CaveShape.WORLD_X0 + 0.5
			var c: Color = rock[Biomes.index_at(z)]
			if CaveShape.outdoors(x, z):
				c = Color("#233522")
			elif CaveShape.in_cave(x, z) or CaveShape.in_tunnel(x, z):
				c = Color("#c8b27a")
			elif st.mask[j * w + i] == 1:
				c = Color("#8a8f96") if CaveShape.in_start(x, z) else Color("#b9c0c8")
			img.set_pixel(i, j, c)
	var colors := {"copper": Color("#c47b58"), "iron": Color("#5fa8d6"), "quartz": Color("#e0c8ff"), "gold": Color("#ffd24a"), "wood": Color("#3fbf5a")}
	for key: Vector2i in st.block_types:
		var item: String = st.block_types[key]
		img.fill_rect(Rect2i(key.x * 4 - int(CaveShape.WORLD_X0), key.y * 4 - int(CaveShape.WORLD_Z0), 4, 4), colors.get(item, Color.WHITE))
	for key: Vector2i in st.water_cells:
		img.fill_rect(Rect2i(key.x * 4 - int(CaveShape.WORLD_X0), key.y * 4 - int(CaveShape.WORLD_Z0), 4, 4), Color("#2f7fb8"))
	var o := Vector2i(int(CaveShape.START_X0 - CaveShape.WORLD_X0), int(CaveShape.START_Z0 - CaveShape.WORLD_Z0))
	var sz := Vector2i(TerrainState.START_W, TerrainState.START_H)
	for i in sz.x:
		img.set_pixel(o.x + i, o.y, Color.WHITE)
	for j in sz.y:
		img.set_pixel(o.x, o.y + j, Color.WHITE)
		img.set_pixel(o.x + sz.x - 1, o.y + j, Color.WHITE)
	var bz := int(Biomes.north_z(0) - CaveShape.WORLD_Z0)
	for i in range(0, w, 3):
		img.set_pixel(i, bz, Color("#ff5050"))
	for p: Dictionary in st.portals:
		img.fill_rect(Rect2i(int(p["x"] - CaveShape.WORLD_X0) - 2, int(p["z"] - CaveShape.WORLD_Z0) - 2, 5, 5), Color("#d040ff") if p["threat"] == 1 else Color("#ff2020"))
	img.save_png(out)
	print("aperçu : ", out)
	quit()
