extends "res://tests/test_case.gd"
## Étape 3 (v2) : A* identique au prototype sur 30 chemins témoins (fixtures 73b410f, état initial).

const Fixtures := preload("res://tests/fixtures.gd")
const GALLERY_SEED := 20261114


func test_paths_match_js() -> void:
	var f := Fixtures.load_json("paths")
	var state := TerrainState.new()
	state.groves = false
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
	state.groves = false
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


## Réserve du coffre ouverte : l'entrée (couloir creusé d'une case, raccord en biais avec la paroi est de
## la salle) a des coins de roche où la ligne droite passe entre deux échantillons et où le glissement axe
## par axe de Simulation.move se coinçait (vers (57, −143,5)). Aller et retour depuis plusieurs points.
func test_reaches_chest_reserve() -> void:
	var sim: Simulation = preload("res://tests/econ_case.gd").new().game()
	sim.world.dig_cell(14, -37)
	sim.world.dig_cell(15, -37)
	check(sim.state().vault_open, "réserve ouverte")
	var u: Unit = GameState.units[0]
	var dt := 1.0 / 60.0
	for start: Vector2 in [Vector2(24, -104), Vector2(50, -120), Vector2(54, -135), Vector2(4, -99), Vector2(-32, -99)]:
		for leg in 2:
			var from := start if leg == 0 else CaveShape.CHEST_SPOT
			var to := CaveShape.CHEST_SPOT if leg == 0 else start
			u.x = from.x
			u.z = from.y
			u.memo = {}
			var t := 0.0
			while u.pos().distance_to(to) > 0.5 and t < 20.0:
				sim.move(u, sim.steer(u, to), dt)
				t += dt
			check(t < 20.0, "%s → %s en moins de 20 s (arrêt en %s)" % [from, to, u.pos()])
