extends "res://tests/test_case.gd"
## Monde procédural, étape 1 : bandes de biomes vers le nord, carte doublée, extension hors zone d'origine.
const Blocks := preload("res://data/mineable_blocks.gd")


func test_bands_stack_north() -> void:
	check_eq(Biomes.at(0.0)["id"], "temple", "base et jungle dans le Temple")
	check_eq(Biomes.at(CaveShape.CORE.y)["id"], "temple", "Ancre dans le Temple")
	check_eq(Biomes.at(CaveShape.START_Z0)["id"], "temple", "zone d'origine entière dans le Temple")
	check_eq(Biomes.north_z(0), Biomes.BASE_Z - 330.0, "hauteur fixe du Temple")
	check_eq(Biomes.at(Biomes.north_z(0) - 1.0)["id"], "biome2", "au-delà : biome 2")
	check_eq(Biomes.at(CaveShape.WORLD_Z0)["id"], "biome2", "bord nord")
	check_eq(Biomes.north_z(1), -INF, "dernier biome sans limite")


func test_map_doubled() -> void:
	check_eq(TerrainState.GAL_W, 2 * TerrainState.START_W, "largeur doublée")
	check_eq(TerrainState.GAL_H, 2 * TerrainState.START_H, "hauteur doublée")


func test_extension_is_deterministic_and_outside_start() -> void:
	var a := TerrainState.new()
	a.generate_galleries(42)
	var b := TerrainState.new()
	b.generate_galleries(42)
	check_eq(a.mask, b.mask, "même graine, même carte")
	var parity := TerrainState.new()
	parity.groves = false
	parity.generate_galleries(42)
	var ext := 0
	var biome2 := 0
	for k in a.mask.size():
		if a.mask[k] == 0:
			continue
		var x := k % TerrainState.GAL_W + CaveShape.WORLD_X0 + 0.5
		var z := k / TerrainState.GAL_W + CaveShape.WORLD_Z0 + 0.5
		if not CaveShape.in_start(x, z):
			ext += 1
			if Biomes.index_at(z) == 1:
				biome2 += 1
	check(ext > 20000, "galeries dans l'extension (%d)" % ext)
	check(biome2 > 0, "galeries dans le biome 2")
	check(a.portals.size() > parity.portals.size(), "portails de l'extension en plus")
	var seen_ext := false
	for p: Dictionary in a.portals:
		var inside := CaveShape.in_start(p["x"], p["z"])
		check(not (inside and seen_ext), "portails de la zone d'origine en tête")
		seen_ext = seen_ext or not inside


func _gen(map_seed: int) -> TerrainState:
	var st := TerrainState.new()
	st.generate_galleries(map_seed)
	return st


func test_extension_content_per_biome() -> void:
	for map_seed in [3, 42, 20261114]:
		var t0 := Time.get_ticks_msec()
		var st := _gen(map_seed)
		var ms := Time.get_ticks_msec() - t0
		var groves := [0, 0]
		var lodes := [0, 0]
		var veins := [0, 0]
		var pools := [0, 0]
		for o: Vector2i in st.wood_left:
			if not CaveShape.in_start(o.x * 4.0, o.y * 4.0):
				groves[Biomes.index_at(o.y * 4.0)] += 1
		for o: Vector2i in st.lodes:
			var z := o.y * 4.0
			if CaveShape.in_start(o.x * 4.0, z):
				continue
			var k := Biomes.index_at(z)
			lodes[k] += 1
			# Le filon (2 × 2 cases) est posé à quelques cases du centre de sa clairière, où le minerai a été tiré.
			var allowed := false
			for dz: float in [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0, 16.0]:
				allowed = allowed or Biomes.ores_at(k, Biomes.depth(k, z + dz)).has(st.lodes[o])
			check(allowed, "filon %s permis à sa profondeur (%s, biome %d, profondeur %.2f)" % [st.lodes[o], o, k, Biomes.depth(k, z)])
		for key: Vector2i in st.block_types:
			var item: String = st.block_types[key]
			if not Blocks.ORES.has(item) or st.lode_cells.has(key) or CaveShape.in_start(key.x * 4.0, key.y * 4.0):
				continue
			var k := Biomes.index_at(key.y * 4.0)
			veins[k] += 1
			check(Biomes.ores_at(k, Biomes.depth(k, key.y * 4.0 + 2.0)).size() > 0, "minerai en paroi dans une bande à minerai")
		for p: Dictionary in st.pools:
			var c: Vector2 = p["center"]
			if not CaveShape.in_start(c.x, c.y):
				pools[Biomes.index_at(c.y)] += 1
		print("     graine %d (%d ms) : bosquets %s, filons %s, parois %s, bassins %s" % [map_seed, ms, groves, lodes, veins, pools])
		for k in 2:
			check(groves[k] > 0 and lodes[k] > 0 and veins[k] > 20, "biome %d garni" % k)
		# Chaque minerai reste dans les biomes qui le portent : pas d'or sur la carte, fer et quartz hors du Temple.
		for key: Vector2i in st.block_types:
			var item: String = st.block_types[key]
			if Blocks.ORES.has(item) and not (Biomes.LIST[Biomes.index_at(key.y * 4.0)]["ores"] as Dictionary).has(item):
				check(false, "%s hors de son biome en %s" % [item, key])
				break


func test_portal_threat_follows_biome() -> void:
	var st := _gen(42)
	var seen := {}
	for p: Dictionary in st.portals:
		check_eq(p["threat"], Biomes.at(p["z"])["threat"], "menace du portail")
		seen[p["threat"]] = true
	check(seen.has(1) and seen.has(2), "portails dans les deux biomes")


## Les passages s'arrêtent avant la galerie d'origine : la zone d'origine reste séparée de l'extension,
## mais à une ou deux cases près.
func test_passages_stop_short_of_start_galleries() -> void:
	for map_seed in [3, 42, 20261114]:
		var st := AfterPassages.new()
		st.generate_galleries(map_seed)
		# Réseaux tels que les passages les laissent : les salles posées ensuite (pylônes, salles à thème)
		# peuvent, elles, déborder sur un passage. Galerie d'origine = déjà là avant les passages (un passage
		# entre lui-même loin dans la zone quand la galerie visée est loin du bord).
		var final_mask := st.mask
		st.mask = st.after_passages
		var comp := _components(st)
		st.mask = final_mask
		var start_ids := {}
		var ext_ids := {}
		for k in st.mask.size():
			if comp[k] == 0:
				continue
			var x := k % TerrainState.GAL_W + CaveShape.WORLD_X0 + 0.5
			var z := k / TerrainState.GAL_W + CaveShape.WORLD_Z0 + 0.5
			if st.before_passages[k] != 0 and TerrainState.gallery_allowed(x, z) and not TerrainState.ext_allowed(x, z) and CaveShape.in_start(x, z):
				start_ids[comp[k]] = true
			if TerrainState.ext_allowed(x, z):
				ext_ids[comp[k]] = true
		for id in start_ids:
			check(not ext_ids.has(id), "graine %d : aucun réseau ne relie déjà l'origine à l'extension" % map_seed)
		# Au moins deux passages arrivent à moins de 3 cases d'une galerie d'origine.
		var close := 0
		for side: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
			var t: Variant = st._edge_gallery(side)
			if t == null:
				continue
			var near := INF
			for k in st.mask.size():
				if st.mask[k] == 0 or start_ids.has(comp[k]):
					continue
				var q := Vector2(k % TerrainState.GAL_W + CaveShape.WORLD_X0 + 0.5, k / TerrainState.GAL_W + CaveShape.WORLD_Z0 + 0.5)
				if absf(q.x - t.x) < 14.0 and absf(q.y - t.y) < 14.0:
					near = minf(near, q.distance_to(t))
			if near <= 12.0:
				close += 1
		check(close >= 2, "graine %d : passages tout près de la zone d'origine (%d)" % [map_seed, close])


## Garde le masque des galeries juste après le percement des passages.
class AfterPassages extends TerrainState:
	var before_passages: PackedByteArray
	var after_passages: PackedByteArray

	func _carve_passages() -> void:
		before_passages = mask.duplicate()
		super()
		after_passages = mask.duplicate()


static func _components(st: TerrainState) -> PackedInt32Array:
	var comp := PackedInt32Array()
	comp.resize(st.mask.size())
	var n := 0
	var w := TerrainState.GAL_W
	for k0 in st.mask.size():
		if st.mask[k0] == 0 or comp[k0] != 0:
			continue
		n += 1
		var stack: Array[int] = [k0]
		while not stack.is_empty():
			var k: int = stack.pop_back()
			if k < 0 or k >= st.mask.size() or st.mask[k] == 0 or comp[k] != 0:
				continue
			comp[k] = n
			var i := k % w
			if i > 0:
				stack.append(k - 1)
			if i < w - 1:
				stack.append(k + 1)
			stack.append(k - w)
			stack.append(k + w)
	return comp
