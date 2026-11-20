extends "res://tests/test_case.gd"
## Étape 3 (v2) : le scénario de creusement de référence (tunnel vers une galerie) produit le même état
## que le prototype : cases creusées, galerie découverte, portail éveillé, nombre d'objets du décor.

const Fixtures := preload("res://tests/fixtures.gd")


func _registry() -> DecorRegistry:
	var reg := DecorRegistry.new()
	var placements: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/world/decor_placements.json"))["placements"]
	for p: Dictionary in placements:
		reg.add_raw(p.duplicate())
	return reg


func test_dig_scenario_matches_js() -> void:
	var f := Fixtures.load_json("dig_scenario")
	var state := TerrainState.new()
	state.groves = false
	state.generate_galleries(int(f["seed"]))
	var reg := _registry()
	check_eq(reg.size(), int(f["objs_before"]), "objets du décor avant")
	var ops := TerrainOps.new(state, reg)
	var v0 := state.version
	for c: Array in f["cells"]:
		ops.dig_cell(int(c[0]), int(c[1]))
	var dug: Array[String] = []
	for k: Vector2i in state.dug:
		dug.append("%d,%d" % [k.x, k.y])
	dug.sort()
	var expected: Array = f["dug"]
	check_eq(dug.size(), expected.size(), "nombre de cases creusées")
	check_eq(state.found, int(f["found"]), "galeries découvertes")
	check_eq(state.open_sha1(), f["open_sha1"], "masque des galeries ouvertes")
	var active: Array = []
	for p in state.portals:
		if p["active"]:
			active.append(Vector2(p["x"], p["z"]))
	var exp_active: Array = []
	for p: Dictionary in f["active_portals"]:
		exp_active.append(Vector2(p["x"], p["z"]))
	check_eq(active, exp_active, "portails maléfiques éveillés")
	check_eq(reg.size(), int(f["objs_after"]), "objets du décor après")
	check(state.version > v0, "praticabilité invalidée")


func test_dig_cell_at_rules() -> void:
	var state := TerrainState.new()
	state.groves = false
	state.generate_galleries(20261114)
	# Une case de la salle (praticable) n'est pas creusable ; la roche voisine de la paroi est l'est.
	check(state.dig_cell_at(0, -35, Vector2(2, -138)) == null, "case praticable")
	var c: Variant = state.diggable_cell(Vector2(58, -138))
	check(c != null, "roche à l'est de la salle")
	if c != null:
		check(state.walkable((c["at"] as Vector2).x, (c["at"] as Vector2).y), "position de travail praticable")
	# Le mur nord de la salle (ancien mur des portails) se creuse désormais ; seul le bord de la carte résiste.
	check(state.dig_cell_at(0, -43, Vector2(2, -165)) != null, "mur nord creusable")
	var edge := floori(CaveShape.WORLD_X0 / 4.0)
	check(state.dig_cell_at(edge, -35, Vector2(edge * 4.0 + 5.0, -138)) == null, "bord de la carte")


func test_engineer_dig_reach() -> void:
	var state := TerrainState.new()
	state.groves = false
	state.generate_galleries(20261114)
	var c: Variant = state.diggable_cell(Vector2(58, -138))
	check(c != null, "roche à l'est de la salle")
	if c == null:
		return
	var i: int = c["i"]
	var j: int = c["j"]
	check(state.in_dig_reach(i, j, c["at"]), "au contact de la case")
	# La case creusée sert de couloir : la case suivante, à l'est, est visée depuis son côté ouest.
	state.dug[Vector2i(i, j)] = true
	state.version += 1
	var x := i * 4.0
	var z := j * 4.0 + 2.0
	check(state.dig_cell_at(i + 1, j, Vector2(x + 0.5, z)) != null, "case suivante creusable")
	check(state.in_dig_reach(i + 1, j, Vector2(x + 0.5, z)), "à 3,5 unités : à portée (une case)")
	check(state.in_dig_reach(i + 1, j, Vector2(x + 3.5, z)), "au contact")
	check(not state.in_dig_reach(i + 1, j, Vector2(x - 0.6, z)), "à 4,6 unités : hors de portée")
	# Face à un coin (en diagonale) : hors de portée.
	check(not state.in_dig_reach(i + 1, j + 1, Vector2(x + 3.5, z + 1.5)), "pas de tir par un coin")
	# De la roche entre l'Ingénieur et la case : hors de portée.
	check(not state.in_dig_reach(i + 2, j, Vector2(x + 3.5, z)), "pas de tir à travers la roche")
