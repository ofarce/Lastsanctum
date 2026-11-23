extends Node
## Contrôle du Temple en salles sur la vraie carte (TerrainState.generate_galleries) : chemins depuis l'Ancre, murs,
## portes, pylônes, salles à thème, filons et bosquets, tanières d'errants ; image du Temple.
##   godot --headless --path . res://tools/worldgen/temple_check.tscn -- <graine> <sortie.png>
## (Scène et non script -s : TerrainState lit l'autoload GameState.)

var _fails := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := int(args[0]) if args.size() > 0 else 20261114
	var out := args[1] if args.size() > 1 else "user://temple_check.png"
	var t0 := Time.get_ticks_msec()
	var st := TerrainState.new()
	st.generate_galleries(map_seed)
	print("Génération : %d ms" % (Time.get_ticks_msec() - t0))
	var lay := st.temple_layout
	_check(not lay.is_empty(), "plan du Temple présent")
	var fz := TerrainState.frontier_z() + TerrainState.FRONTIER_HALF
	# Chaque salle taillée est reliée à l'Ancre, sauf les secrètes (derrière leur fissure).
	for room: Dictionary in lay["rooms"]:
		var c := Vector2((room["rect"] as Rect2i).get_center()) * 4.0 + Vector2(2, 2)
		var d := st.path_at(c.x, c.y)
		if room["kind"] == "secret":
			_check(d < 0.0, "salle secrète %d isolée (chemin %.0f)" % [room["id"], d])
			if d >= 0.0:
				_explain_leak(st, room)
		else:
			_check(d >= 0.0, "salle %d (%s %s) reliée à l'Ancre" % [room["id"], room["kind"], room["role"]])
	# Murs impossibles à creuser et sans galerie ; portes ouvertes et praticables.
	# Arène de la Martyre : assez grande pour son dôme (rayon Martyre.RADIUS), dans le quartier B.
	var arena := Martyre.arena_room(st)
	var ar: Rect2i = arena["rect"]
	_check(arena["quarter"] == "B" and minf(ar.size.x, ar.size.y) * 4.0 >= 2.0 * Martyre.RADIUS, "arène de la Martyre %s assez grande pour le dôme" % ar)
	var wall_open := 0
	for key: Vector2i in st.room_walls:
		_check(not st.minable_block(key.x, key.y), "mur %s impossible à creuser" % key)
		if st.is_gallery(key.x * 4.0 + 2.0, key.y * 4.0 + 2.0):
			wall_open += 1
	_check(wall_open == 0, "aucun mur creux (%d)" % wall_open)
	# (Hors du monde, aucune galerie n'est encore découverte : walkable serait faux partout.)
	# mb1 et mb2 scellées jusqu'à la chute de leur mini-boss (Archiprêtre, Martyre).
	for key: Vector2i in st.door_cells:
		var closed: bool = st.doors_closed[st.door_cells[key]]
		_check(closed, "porte %s (%s) fermée" % [key, st.door_cells[key]])
		if closed:
			_check(not st.is_gallery(key.x * 4.0 + 2.0, key.y * 4.0 + 2.0) and not st.minable_block(key.x, key.y), "porte %s scellée" % key)
		else:
			_check(st.is_gallery(key.x * 4.0 + 2.0, key.y * 4.0 + 2.0), "porte %s creusée et ouverte" % key)
	# Pylônes : trois au Temple, chacun dans sa salle.
	var temple_pylons := st.portals.filter(func(p: Dictionary) -> bool: return p["z"] > fz)
	_check(temple_pylons.size() == 3, "3 pylônes au Temple (%d)" % temple_pylons.size())
	for p: Dictionary in temple_pylons:
		var room := st.temple_room(p["x"], p["z"])
		_check(not room.is_empty() and room["pylon"], "pylône %d dans une salle à pylône" % p["id"])
	# Salles à thème : quinze, dans des salles du plan.
	_check(st.theme_rooms.size() == TerrainState.THEME_ROOMS, "%d salles à thème" % st.theme_rooms.size())
	for t: Dictionary in st.theme_rooms:
		_check(not st.temple_room(t["x"], t["z"]).is_empty(), "salle à thème %s dans une salle" % t["kind"])
	# Filons et bosquets du Temple.
	var lodes := st.lodes.keys().filter(func(k: Vector2i) -> bool: return k.y * 4.0 > fz)
	var groves := st.wood_left.keys().filter(func(k: Vector2i) -> bool: return k.y * 4.0 > fz)
	print("Temple : %d filons, %d bosquets (grotte comprise), %d bassins, %d cases de mur, %d de porte" % [
		lodes.size(), groves.size(), st.pools.filter(func(p: Dictionary) -> bool: return (p["center"] as Vector2).y > fz).size(),
		st.room_walls.size(), st.door_cells.size()])
	_check(lodes.size() >= 4, "au moins 4 filons de cuivre")
	_check(groves.size() >= 5, "au moins 5 bosquets")
	# Tanières d'errants : au Temple, seulement dans des salles de combat.
	var dens := Roamers.dens(st, map_seed)
	var temple_dens := dens.filter(func(d: Dictionary) -> bool: return d["z"] > fz)
	for d: Dictionary in temple_dens:
		var room := st.temple_room(d["x"], d["z"])
		_check(not room.is_empty() and room["kind"] == "combat", "tanière (%.0f, %.0f) dans un combat" % [d["x"], d["z"]])
	print("Tanières : %d au Temple sur %d" % [temple_dens.size(), dens.size()])
	_render(st, temple_dens, out)
	print("Échecs : %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Cases creuses qui touchent la salle secrète depuis l'extérieur, et ce qui les a creusées.
func _explain_leak(st: TerrainState, room: Dictionary) -> void:
	var rr: Rect2i = room["rect"]
	var g := rr.grow(1)
	for i in range(g.position.x, g.end.x):
		for j in range(g.position.y, g.end.y):
			if rr.has_point(Vector2i(i, j)):
				continue
			var p := Vector2(i * 4.0 + 2.0, j * 4.0 + 2.0)
			if not st.is_gallery(p.x, p.y):
				continue
			var why := []
			for l: Dictionary in st.temple_layout["links"]:
				if l["kind"] == "corridor" and RoomLayout.corridor_cells(l["path"]).has(Vector2i(i, j)):
					why.append("couloir %d→%d" % [l["a"], l["b"]])
			for pp: Dictionary in st.portals:
				if Vector2(pp["x"], pp["z"]).distance_to(p) < TerrainState.PYLON_CHAMBER + 3.0:
					why.append("salle du pylône %d" % pp["id"])
			for pool: Dictionary in st.pools:
				if (pool["center"] as Vector2).distance_to(p) < TerrainState.POOL_RADIUS + 3.0:
					why.append("bassin")
			print("   fuite en (%d, %d) : %s" % [i, j, ", ".join(why) if not why.is_empty() else "?"])


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("ÉCHEC : ", what)


## Le Temple seul, 2 px par unité : galeries, grotte, murs, portes, filons, bosquets, eau, pylônes, salles à thème,
## tanières.
func _render(st: TerrainState, dens: Array, out: String) -> void:
	var z0 := -424.0
	var z1 := -70.0
	var w := int(CaveShape.WORLD_X1 - CaveShape.WORLD_X0)
	var h := int(z1 - z0)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for j in h:
		var z := z0 + j + 0.5
		for i in w:
			var x := CaveShape.WORLD_X0 + i + 0.5
			var c := Color("#1c222d")
			if CaveShape.outdoors(x, z):
				c = Color("#233522")
			elif CaveShape.in_cave(x, z) or CaveShape.in_tunnel(x, z):
				c = Color("#c8b27a")
			elif st.is_gallery(x, z):
				c = Color("#8a98a8")
			elif absf(z - TerrainState.frontier_z()) < TerrainState.FRONTIER_HALF:
				c = Color("#3a1418")
			img.set_pixel(i, j, c)
	var cell := func(key: Vector2i, col: Color) -> void:
		var r := Rect2i(int(key.x * 4 - CaveShape.WORLD_X0), int(key.y * 4 - z0), 4, 4)
		img.fill_rect(r.intersection(Rect2i(0, 0, w, h)), col)
	for key: Vector2i in st.room_walls:
		cell.call(key, Color.BLACK)
	for key: Vector2i in st.door_cells:
		cell.call(key, Color("#ddb457"))
	for key: Vector2i in st.water_cells:
		cell.call(key, Color("#2f7fb8"))
	for key: Vector2i in st.lode_cells:
		cell.call(key, Color("#c47b58"))
	for key: Vector2i in st.grove_cells:
		cell.call(key, Color("#3fbf5a"))
	for key: Vector2i in st.block_types:
		if not st.lode_cells.has(key) and not st.grove_cells.has(key):
			cell.call(key, Color("#e09a78"))
	for t: Dictionary in st.theme_rooms:
		var half: Vector2i = t["half"]
		var r := Rect2i(int(t["x"] - CaveShape.WORLD_X0) - half.x * 4 - 2, int(t["z"] - z0) - half.y * 4 - 2, half.x * 8 + 4, half.y * 8 + 4)
		for i in range(r.position.x, r.end.x):
			img.set_pixel(i, r.position.y, Color("#5fd8e8"))
			img.set_pixel(i, r.end.y - 1, Color("#5fd8e8"))
		for j in range(r.position.y, r.end.y):
			img.set_pixel(r.position.x, j, Color("#5fd8e8"))
			img.set_pixel(r.end.x - 1, j, Color("#5fd8e8"))
	for p: Dictionary in st.portals:
		if p["z"] > z0:
			img.fill_rect(Rect2i(int(p["x"] - CaveShape.WORLD_X0) - 3, int(p["z"] - z0) - 3, 7, 7), Color("#ff2020"))
	for d: Dictionary in dens:
		img.fill_rect(Rect2i(int(d["x"] - CaveShape.WORLD_X0) - 1, int(d["z"] - z0) - 1, 3, 3), Color.WHITE)
	img.resize(w * 2, h * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("Image : ", out)
