extends "res://tests/test_case.gd"
## Rivière de la jungle (world/terrain/river.gd) : eau infranchissable, ponts de pierre praticables,
## chemin des vagues vers l'Ancre par un pont, rive des ennemis non constructible.

const SEED := 20261114


func _state() -> TerrainState:
	var s := TerrainState.new()
	s.generate_galleries(SEED)
	return s


func test_river_spans_the_map_between_mountain_and_spawn() -> void:
	var r := River.new(SEED)
	var x := CaveShape.WORLD_X0
	var ok := true
	while x < CaveShape.WORLD_X1:
		var c := r.center(x)
		var hw := r.half_width(x)
		if c - hw < CaveShape.mountain_edge(x) + 60.0 or c + hw > 58.0 or hw < 2.0:
			ok = false
		x += 1.0
	check(ok, "rivière continue, loin du flanc et au nord de l'arrivée des vagues (z 62)")
	check(r.bridges.size() >= 3 and r.bridges.size() <= 5, "3 à 5 ponts")
	check(not r.bridge_near(0.0).is_empty(), "un pont sur le chemin (x = 0)")


func test_deterministic() -> void:
	var a := River.new(SEED)
	var b := River.new(SEED)
	check_eq(a.center(123.4), b.center(123.4), "même graine, même tracé")
	check_eq(a.bridges, b.bridges, "même graine, mêmes ponts")
	check(River.new(SEED + 1).center(123.4) != a.center(123.4), "autre graine, autre tracé")


func test_water_blocks_bridges_pass() -> void:
	var s := _state()
	var r := s.river
	check(r != null, "rivière générée")
	var x := 60.0
	if not r.bridge_near(x).is_empty():
		x = 200.0
	check(not s.walkable(x, r.center(x)), "eau infranchissable hors pont")
	for b in r.bridges:
		var bx: float = b["x"]
		check(s.walkable(bx + 1.0, r.center(bx)), "tablier praticable (pont %d)" % bx)
		check(not s.walkable(bx + River.DECK_HALF + 0.4, r.center(bx)), "parapet infranchissable (pont %d)" % bx)


func test_waves_reach_the_anchor_over_a_bridge() -> void:
	var s := _state()
	var pf := Pathfinder.new(s)
	var path: Variant = pf.find_path(Vector2(0, 62), CaveShape.CORE + Vector2(0, 6))
	check(path != null, "chemin des vagues vers l'Ancre")
	# Loin du pont : le chemin doit faire le détour par un pont.
	var far := Vector2(60.0, 64.0)
	var p2: Variant = pf.find_path(far, Vector2(60.0, 0.0))
	check(p2 != null, "traversée possible depuis x = 60")
	if p2 != null:
		var crossed := false
		var prev := far
		for q: Vector2 in p2:
			var mid := (prev + q) * 0.5
			if not s.river.bridge_near(mid.x).is_empty():
				crossed = true
			prev = q
		check(crossed, "la traversée passe par un pont")


func test_far_bank_and_bridges_not_buildable() -> void:
	var r := River.new(SEED)
	var x := 30.0
	check(r.far_bank(x, r.center(x) + r.half_width(x) + 3.0), "rive sud = rive des ennemis")
	check(not r.far_bank(x, r.center(x) - r.half_width(x) - 3.0), "rive nord = zone de combat")


func test_flood_hook() -> void:
	var r := River.new(SEED)
	var x := 30.0
	var z := r.center(x) - r.half_width(x) - 1.0
	check(not r.flooded(x, z), "pas de crue au repos")
	r.flood = 3.0
	check(r.flooded(x, z), "la crue couvre la berge")
	check(not r.water_at(x, z), "la zone inondée n'est pas le lit")


func test_parity_mode_has_no_river() -> void:
	var s := TerrainState.new()
	s.groves = false
	s.generate_galleries(SEED)
	check(s.river == null, "parité JS : pas de rivière")
