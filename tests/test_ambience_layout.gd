extends "res://tests/test_case.gd"
## Ambiances de la montagne (planche ambiances-montagne-detail.html) : placement déterministe et
## parcimonieux, fosses des bassins infranchissables, rien sur les cases de minerai ou les bosquets.

const SEED := 20261114


func _state(seed := SEED) -> TerrainState:
	var s := TerrainState.new()
	s.generate_galleries(seed)
	return s


func test_layout_is_deterministic() -> void:
	var a := AmbienceLayout.build(_state())
	var b := AmbienceLayout.build(_state())
	check(var_to_str(a) == var_to_str(b), "même graine, mêmes ambiances")
	var c := AmbienceLayout.build(_state(SEED + 1))
	check(var_to_str(a) != var_to_str(c), "autre graine, autres ambiances")


func test_pools_are_rare_and_deep_water_blocks() -> void:
	var s := _state()
	var inner := s.pools.filter(func(p: Dictionary) -> bool: return CaveShape.in_start((p["center"] as Vector2).x, (p["center"] as Vector2).y))
	# La source de C est devenue un combat (2026-11-22, RoomLayout) : le Temple peut n'avoir aucun bassin.
	check(inner.size() <= TerrainState.POOL_COUNT, "zone d'origine : au plus %d bassins (%d)" % [TerrainState.POOL_COUNT, inner.size()])
	check(not s.water_cells.is_empty(), "chaque carte a des cases de fosse")
	for key: Vector2i in s.water_cells:
		var x := key.x * 4.0 + 2.0
		var z := key.y * 4.0 + 2.0
		check(s.water_at(x, z), "water_at sur une case de fosse")
		s.open.fill(1)
		s.found = 1
		check(not s.walkable(x, z), "fosse infranchissable (%s)" % key)
	for i in s.pools.size():
		for j in range(i + 1, s.pools.size()):
			check((s.pools[i]["center"] as Vector2).distance_to(s.pools[j]["center"]) >= 90.0, "bassins espacés")


func test_shallow_water_stays_walkable() -> void:
	var s := _state()
	s.open.fill(1)
	s.found = 1
	var shallow := 0
	for p: Dictionary in s.pools:
		var c: Vector2 = p["center"]
		for dz in range(-12, 13):
			for dx in range(-14, 15):
				var x := c.x + dx + 0.5
				var z := c.y + dz + 0.5
				var f := TerrainState.pool_field(p, x, z)
				if f > TerrainState.POOL_EDGE and f < 1.3 and not s.water_at(x, z) and s.is_gallery(x, z):
					check(s.walkable(x, z), "haut-fond praticable")
					shallow += 1
	check(shallow > 0, "les bassins ont un haut-fond")


func test_nothing_on_ores_groves_or_water() -> void:
	var s := _state()
	var a := AmbienceLayout.build(s)
	for key: String in ["mushrooms", "vines", "roots", "beetles"]:
		for d: Dictionary in a[key]:
			var k := Vector2i(floori(d["x"] / 4.0), floori(d["z"] / 4.0))
			check(not s.block_types.has(k) and not s.grove_cells.has(k) and not s.lode_cells.has(k) and not s.water_cells.has(k),
				"%s hors minerai, bosquet, filon et fosse (%s)" % [key, k])
			# Case ouverte au sens du rendu des parois (centre de la case en galerie).
			check(s.is_gallery(k.x * 4.0 + 2.0, k.y * 4.0 + 2.0), "%s dans une case de galerie" % key)


func test_sparse_quotas() -> void:
	var s := _state()
	var a := AmbienceLayout.build(s)
	var chunks := ceili((CaveShape.WORLD_X1 - CaveShape.WORLD_X0) / 32.0) * ceili((CaveShape.WORLD_Z1 - CaveShape.WORLD_Z0) / 32.0)
	check(a["mushrooms"].size() <= chunks * 0.5 + s.pools.size(), "champignons rares (%d pour %d chunks)" % [a["mushrooms"].size(), chunks])
	for d: Dictionary in a["vines"] + a["roots"]:
		check(d["z"] > CaveShape.mountain_edge(d["x"]) - AmbienceLayout.VINE_BAND - 32.0, "lianes et racines près de la jungle seulement")
	var groups: Array = a["bats"] + a["beetles"]
	for i in groups.size():
		for j in range(i + 1, groups.size()):
			var p := Vector2(groups[i]["x"], groups[i]["z"])
			var q := Vector2(groups[j]["x"], groups[j]["z"])
			check(p.distance_to(q) >= AmbienceLayout.FAUNA_GAP or groups[i] in a["bats"] and groups[j] in a["bats"],
				"un groupe de faune par écran")


func test_no_pools_without_groves() -> void:
	var s := TerrainState.new()
	s.groves = false
	s.generate_galleries(SEED)
	check(s.pools.is_empty() and s.water_cells.is_empty(), "parité JS : pas de bassin quand groves = false")
