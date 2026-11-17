extends "res://tests/test_case.gd"
## Étape 3 (v2) : galeries, praticabilité et cases à creuser identiques au prototype (fixtures 73b410f).

const Fixtures := preload("res://tests/fixtures.gd")
const GALLERY_SEED := 20261114


func test_galleries_match_js_for_5_seeds() -> void:
	var f := Fixtures.load_json("galleries")
	check_eq(f["results"].size(), 5, "graines")
	var state := TerrainState.new()
	for res: Dictionary in f["results"]:
		state.groves = false
		state.generate_galleries(int(res["seed"]))
		var cells := 0
		for v in state.mask:
			cells += v
		check_eq(cells, int(res["cells"]), "graine %d : cases de galerie" % res["seed"])
		check_eq(state.mask_sha1(), res["mask_sha1"], "graine %d : masque" % res["seed"])
		check_eq(state.count, int(res["count"]), "graine %d : réseaux" % res["seed"])
		check_eq(state.portals.size(), res["portals"].size(), "graine %d : portails" % res["seed"])
		for n in mini(state.portals.size(), res["portals"].size()):
			check_eq(Vector2(state.portals[n]["x"], state.portals[n]["z"]), Vector2(res["portals"][n]["x"], res["portals"][n]["z"]), "portail %d" % n)


func test_walkable_matches_js() -> void:
	var f := Fixtures.load_json("walkable")
	var state := TerrainState.new()
	state.groves = false
	state.generate_galleries(GALLERY_SEED)
	var wrong := 0
	var first := ""
	for s: Array in f["samples"]:
		var x: float = s[0]
		var z: float = s[1]
		var got := [1 if state.walkable(x, z) else 0, 1 if CaveShape.in_cave(x, z) else 0, 1 if CaveShape.in_tunnel(x, z) else 0]
		if got != [int(s[2]), int(s[3]), int(s[4])]:
			wrong += 1
			if first.is_empty():
				first = "(%s, %s) : attendu %s, obtenu %s" % [x, z, s.slice(2), got]
	check_eq(wrong, 0, "points en désaccord sur 4000 " + first)


func test_push_out_of_rock_lands_on_walkable_ground() -> void:
	var state := TerrainState.new()
	state.groves = false
	state.generate_galleries(GALLERY_SEED)
	var r := Rng.new(5)
	for i in 200:
		var p := Vector2(-200.0 + r.next() * 400.0, -330.0 + r.next() * 400.0)
		var q := state.push_out_of_rock(p)
		check(state.walkable(q.x, q.y) or CaveShape.in_cave(q.x, q.y) or absf(q.x) < CaveShape.CAVE_GATE \
			or q.y >= CaveShape.mountain_edge(q.x), "point replacé sur un sol praticable : %s" % q)
