extends "res://tests/test_case.gd"
## Galeries orthogonales, génération déterministe et praticabilité du terrain.

const Fixtures := preload("res://tests/fixtures.gd")
const GALLERY_SEED := 20261114


class TunnelTrace extends TerrainState:
	var points: Array[Vector2] = []

	func _stamp(x: float, z: float, _radius: float) -> void:
		points.append(Vector2(x, z))

	func _stamp_free(x: float, z: float, _radius: float) -> void:
		points.append(Vector2(x, z))


func test_tunnel_steps_are_orthogonal() -> void:
	for map_seed in [1, 42, 12345, GALLERY_SEED, 987654321]:
		for direction in 4:
			var trace := TunnelTrace.new()
			trace._worm(Rng.new(map_seed), -140.0, -250.0, direction, 200, 2.5, {"room": 0.0, "branch": 0.0})
			for i in range(1, trace.points.size()):
				var delta := trace.points[i] - trace.points[i - 1]
				check(is_zero_approx(delta.x) or is_zero_approx(delta.y), "pas orthogonal : %s" % delta)
	var passage := TunnelTrace.new()
	passage._carve_axis_segment(Vector2(-150, -250), Vector2(-150, -258))
	passage._carve_axis_segment(Vector2(-150, -258), Vector2(-120, -258))
	for i in range(1, passage.points.size()):
		var delta := passage.points[i] - passage.points[i - 1]
		check(is_zero_approx(delta.x) or is_zero_approx(delta.y), "raccordement orthogonal : %s" % delta)
	check_eq(passage.points[-1], Vector2(-120, -258), "raccordement jusqu'à l'extrémité")


func test_galleries_are_deterministic_for_5_seeds() -> void:
	for map_seed in [1, 42, 12345, GALLERY_SEED, 987654321]:
		var state := TerrainState.new()
		state.groves = false
		state.generate_galleries(map_seed)
		var other := TerrainState.new()
		other.groves = false
		other.generate_galleries(map_seed)
		check_eq(state.mask, other.mask, "même graine, mêmes galeries")
		check(state.count > 0, "réseaux générés")
		check_eq(state.portals, other.portals, "portails déterministes")


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
