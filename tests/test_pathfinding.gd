extends "res://tests/test_case.gd"
## Étape 3 (v2) : A* identique au prototype sur 30 chemins témoins (fixtures 73b410f, état initial).

const Fixtures := preload("res://tests/fixtures.gd")
const GALLERY_SEED := 20261114


func test_paths_match_js() -> void:
	var f := Fixtures.load_json("paths")
	var state := TerrainState.new()
	state.generate_galleries(GALLERY_SEED)
	var pf := Pathfinder.new(state)
	check_eq(f["paths"].size(), 30, "chemins témoins")
	var t0 := Time.get_ticks_usec()
	for n in f["paths"].size():
		var c: Dictionary = f["paths"][n]
		var got: Variant = pf.find_path(Vector2(c["from"]["x"], c["from"]["z"]), Vector2(c["to"]["x"], c["to"]["z"]))
		if c["path"] == null:
			check(got == null, "chemin %d : aucun chemin attendu" % n)
			continue
		check(got != null, "chemin %d : chemin attendu" % n)
		if got == null:
			continue
		var expected: Array = c["path"]
		var same: bool = (got as Array).size() == expected.size()
		if same:
			for m in expected.size():
				if (got[m] as Vector2) != Vector2(expected[m][0], expected[m][1]):
					same = false
					break
		check(same, "chemin %d : %d points attendus, %d obtenus" % [n, expected.size(), (got as Array).size()])
	print("     (30 chemins en %d ms)" % ((Time.get_ticks_usec() - t0) / 1000))


func test_steer_goes_straight_when_clear() -> void:
	var state := TerrainState.new()
	state.generate_galleries(GALLERY_SEED)
	var pf := Pathfinder.new(state)
	var memo := {}
	check_eq(pf.steer(Vector2(0, -130), Vector2(10, -130), memo), Vector2(10, -130), "ligne de vue dégagée")
	# De la salle à la jungle : la ligne droite traverse la roche, il faut passer par le couloir.
	var goal := Vector2(60, -40)
	check(not pf.clear_line(Vector2(0, -130), goal), "ligne droite bloquée")
	var next := pf.steer(Vector2(0, -130), goal, memo)
	check(next != goal and state.walkable(next.x, next.y), "contournement par un point praticable : %s" % next)
	check(absf(next.x) < CaveShape.CAVE_GATE + 2.0, "le premier point vise le couloir : %s" % next)
