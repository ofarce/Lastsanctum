extends Node
## Empreinte de la carte générée : masque des galeries, minerais, pylônes et portails, au sud d'une limite.
## godot --headless --path . res://tools/worldgen/fingerprint.tscn  (variable FP_ZMIN, défaut −744 ; FP_ALL=1 : toute la carte)
func _ready() -> void:
	var zmin := float(OS.get_environment("FP_ZMIN")) if OS.get_environment("FP_ZMIN") != "" else -744.0
	if OS.get_environment("FP_ALL") == "1":
		zmin = CaveShape.WORLD_Z0
	var t0 := Time.get_ticks_msec()
	var st := TerrainState.new()
	st.generate_galleries(20261114)
	var ms := Time.get_ticks_msec() - t0
	var j0 := int(zmin - CaveShape.WORLD_Z0)
	var rows := st.mask.slice(j0 * TerrainState.GAL_W)
	var opn := st.open.slice(j0 * TerrainState.GAL_W)
	var ores: Array = []
	for key: Vector2i in st.block_types:
		if key.y * 4.0 >= zmin:
			ores.append("%d,%d,%s" % [key.x, key.y, st.block_types[key]])
	ores.sort()
	var perm: Array = []
	for key: Vector2i in st.permanent_ores:
		if key.y * 4.0 >= zmin:
			perm.append(str(key))
	perm.sort()
	var pyl: Array = []
	for p in st.pylons if "pylons" in st else []:
		pyl.append(str(p))
	var por: Array = []
	for p: Dictionary in st.portals:
		if float(p["z"]) >= zmin:
			por.append("%s,%s" % [p["x"], p["z"]])
	por.sort()
	print("ms ", ms, " masque ", _h(rows), " ouvert ", _h(opn),
		" minerais ", ores.size(), " ", "|".join(ores).sha256_text().left(16), " perm ", "|".join(perm).sha256_text().left(16),
		" portails ", por.size(), " ", "|".join(por).sha256_text().left(16), " pylônes ", str(st.pylon_cells).sha256_text().left(16),
		" gorge ", st.gorge_room, " lodes ", str(st.lode_cells.keys()).sha256_text().left(16) if "lode_cells" in st else "")
	get_tree().quit()


static func _h(b: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish().hex_encode().left(16)
