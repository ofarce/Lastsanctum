extends "res://tests/econ_case.gd"
## Bois : arbres pétrifiés par bosquets de 3, inépuisables pour Medeina, abattus après 20 bois sinon.
## Indra frappe deux fois plus fort ; Sigil prie à tout autel (deux fois plus lentement hors du sien).

const Blocks := preload("res://data/mineable_blocks.gd")


func test_groves_generated() -> void:
	var st := TerrainState.new()
	for map_seed in [0, 1, 17, SEED]:
		st.generate_galleries(map_seed)
		check(st.wood_left.size() >= 3, "bosquets, graine %d : %d" % [map_seed, st.wood_left.size()])
		check_eq(st.grove_cells.size(), st.wood_left.size() * 4, "2 × 2 cases par bosquet")
		var start := st.wood_left.keys().filter(func(o: Vector2i) -> bool:
			return (Vector2(o * 4) + Vector2(4, 4)).distance_to(st.START_GROVE_AT) < 16.0)
		check_eq(start.size(), 1, "bosquet de la salle de départ, graine %d" % map_seed)
		for o: Vector2i in st.wood_left:
			var c := Vector2(o * 4) + Vector2(4, 4)
			check((st.ground(c.x, c.y) or st.is_gallery(c.x, c.y)) and not st.walkable(c.x, c.y), "posé au sol et infranchissable")
			check(st.walkable(c.x - 6.0, c.y) or st.walkable(c.x + 6.0, c.y) or not st.is_gallery_open(c.x, c.y), "accessible")


func _start(st: TerrainState) -> Vector2i:
	for o: Vector2i in st.wood_left:
		if (Vector2(o * 4) + Vector2(4, 4)).distance_to(st.START_GROVE_AT) < 16.0:
			return o
	return Vector2i.ZERO


func _miner(sim: Simulation, role: String) -> Array:
	var st := sim.state()
	var o := _start(st)
	var key := o + Vector2i(1, 1)
	var cell: Variant = st.dig_cell_at(key.x, key.y, Vector2(key * 4) + Vector2(6, 6))
	check(cell != null, "bosquet minable")
	var u := sim.spawn("Adepte", cell["at"].x, cell["at"].y, role)
	GameState.selected = [u] as Array[Unit]
	check(sim.order_mining_cells([cell]), "ordre de récolte")
	return [u, o]


func test_medeina_never_depletes() -> void:
	var sim := game()
	var r := _miner(sim, "medeina")
	for i in 30:
		sim.update_adepts(Simulation.adept_mining_seconds(r[0]))
	check_eq(sim.state().wood_left[r[1]], Blocks.WOOD_YIELD, "intact")
	check(sim.state().grove_cells.has(r[1]), "toujours là")


func test_other_adept_fells_tree() -> void:
	var sim := game()
	var r := _miner(sim, "indra")
	for i in 19:
		sim.update_adepts(Simulation.adept_mining_seconds(r[0]))
		sim.update_adepts(0.0)
	check_eq(sim.state().wood_left[r[1]], 1, "19 bois récoltés")
	sim.update_adepts(Simulation.adept_mining_seconds(r[0]))
	sim.update_adepts(0.0)
	var c := Vector2(r[1] * 4) + Vector2(4, 4)
	check(not sim.state().wood_left.has(r[1]) and sim.state().walkable(c.x, c.y), "bosquet abattu après 20 bois, sol libre")
	check(r[0].job == null, "le mineur s'arrête")


func test_indra_double_damage() -> void:
	game()
	var a := Unit.new()
	a.role = "indra"
	var b := Unit.new()
	b.role = "sigil"
	check_eq(Catalog.damage_mult(a), 2.0, "Indra ×2")
	check_eq(Catalog.damage_mult(b), 1.0, "Sigil ×1")


func test_sigil_prays_anywhere() -> void:
	var sim := game()
	var t := built("medeina", -26.0, -118.0)
	var a := sim.spawn("Adepte de Sigil", -26.0, -105.0, "sigil")
	var m := sim.spawn("Adepte d'Indra", -20.0, -105.0, "indra")
	check(Simulation.can_pray_at(a, t) and not Simulation.can_pray_at(m, t), "Sigil seul prie partout")
	check(sim.send_to_pray(a), "autel étranger accepté")
	var spot := sim.prayer_spot(a, t)
	a.x = spot.x
	a.z = spot.y
	var v0: float = GameState.res["vie"]
	GameState.orb_active = false
	sim.update_adepts(2.0)
	check_near(GameState.res["vie"] - v0, 1.0, 1e-6, "+0,5 Vie / s")
	check_eq(Simulation.pray_rate(a, t), 0.5, "moitié du rythme")


func test_wood_reaches_vault_only_on_arrival() -> void:
	var sim := game()
	GameState.base_inventory_unlocked = true
	var u: Unit = _miner(sim, "medeina")[0]
	sim.update_adepts(Simulation.adept_mining_seconds(u))
	check_eq(u.carrying.get("item"), "wood", "le bois voyage avec la récoltante")
	check_eq(Production.count_in(GameState.base_inventory, "wood"), 0, "bois encore en route")
	check_eq(u.carrying.get("quantity"), 1, "première ressource conservée pendant la récolte")
	for i in 4:
		sim.update_adepts(Simulation.adept_mining_seconds(u))
	check_eq(u.carrying.get("quantity"), 5, "départ avec cinq bois")
	sim.update_adepts(0.0)
	check_eq(Vector2(u.tx, u.tz), CaveShape.CHEST_SPOT, "destination du transport")
	u.x = u.tx
	u.z = u.tz
	sim.update_adepts(DT)
	check_eq(Production.count_in(GameState.base_inventory, "wood"), 5, "cinq bois déposés au coffre")
	check(u.carrying.is_empty() and u.job != null, "prête à retourner au bosquet")
