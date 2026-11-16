extends "res://tests/econ_case.gd"
const Storage := preload("res://sim/item_storage.gd")

func test_start_and_armored_stats() -> void:
	var sim := game()
	sim.new_game(SEED)
	var u := engineer()
	check_eq(sim.world.camera.cam, u.pos(), "caméra centrée")
	check_eq(GameState.core_hp, 1.0, "ancre éteinte")
	check_eq(Catalog.attack_damage(u), 1000, "dégâts armure")
	check_eq(Catalog.unit_reach(u), 250.0, "portée armure")
	check_eq(Catalog.armor(u), 500, "défense armure")
	u.unarmored = true
	check_eq(Catalog.attack_damage(u), 5, "dégâts sans armure")
	check_eq(Catalog.armor(u), 0, "défense sans armure")

func test_rally_on_training_and_summoning() -> void:
	var sim := game()
	var b := built("caserne", -24, -120)
	b.rally_point = Vector2(15, -110)
	sim.spawn_trained(b, "archer")
	for u: Unit in GameState.units:
		if u.role == "archer":
			check_eq(Vector2(u.tx, u.tz), b.rally_point, "destination escouade")
			check(u.force_move, "déplacement prioritaire")
	give(1000.0)
	var temple := built("sigil", 24, -120)
	temple.rally_point = Vector2(10, -110)
	sim.summon_adept(temple)
	var adept: Unit = GameState.units.back()
	check_eq(Vector2(adept.tx, adept.tz), temple.rally_point, "destination adepte")
	check(adept.job == null and adept.force_move, "ralliement au lieu de prière")

func test_inventory_moves_swaps_and_merges() -> void:
	var a: Array[Dictionary] = [{"item": "rock", "quantity": 3}]
	var b: Array[Dictionary] = []
	Storage.move_stack(a, 0, a, 5, 10)
	check(a[0].is_empty() and a[5]["quantity"] == 3, "déplacement vers case vide")
	Storage.move_stack(a, 5, b, 9, 100)
	check(a[5].is_empty() and b[9]["quantity"] == 3, "transfert coffre")
	check(Storage.store(a, 10, "rock"), "collecte réutilise case vide")
	Storage.move_stack(b, 9, a, 0, 10)
	check_eq(a[0]["quantity"], 4, "fusion")

func test_building_spacing_and_open_cave() -> void:
	var sim := game()
	check(sim.buildable_ground(0, -130), "allée centrale constructible")
	var b := built("caserne", -24, -120)
	var gap := b.half() + Simulation.half_of("caserne")
	check(not sim.valid_site("caserne", Vector2(b.x + gap, b.z)), "bâtiments adjacents interdits")
	check(sim.valid_site("caserne", Vector2(b.x + gap + 4, b.z)), "une case libre suffit")
