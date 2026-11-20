extends "res://tests/econ_case.gd"
## Coffre antique : la réserve se découvre en minant la paroi est de la salle, l'Ingénieur ouvre le coffre,
## la réserve de la base (100 cases) se débloque.

const ItemStorage := preload("res://sim/item_storage.gd")


func _open_vault(sim: Simulation) -> void:
	sim.world.dig_cell(14, -37)
	sim.world.dig_cell(15, -37)


func test_engineer_opens_chest_and_unlocks_storage() -> void:
	var sim := game()
	check(not sim.order_chest(engineer()), "réserve scellée : pas d'ordre")
	check(not sim.buildable_ground(CaveShape.CHEST.x, CaveShape.CHEST.y), "réserve non constructible")
	_open_vault(sim)
	check(sim.state().vault_open, "réserve découverte")
	check(sim.order_chest(engineer()), "ordre donné")
	check_eq(engineer().job.get("type"), "chest", "tâche coffre")
	var t := 0.0
	while not GameState.base_inventory_unlocked and t < 90.0:
		run(sim, 1.0)
		t += 1.0
	check(GameState.base_inventory_unlocked, "réserve de base débloquée")
	check(not is_inf(GameState.chest_opened_at), "instant d'ouverture noté")
	check(engineer().job == null, "tâche terminée")
	check(engineer().pos().distance_to(CaveShape.CHEST_SPOT) < 0.8, "Ingénieur devant le coffre")
	ItemStorage.deposit("rock", engineer(), engineer().pos())
	check_eq(GameState.base_inventory, [{"item": "rock", "quantity": 1}], "objets vers la réserve")
	var asked := [0]
	var cb := func() -> void: asked[0] += 1
	Events.inventory_requested.connect(cb)
	check(sim.order_chest(engineer()) and asked[0] == 1, "coffre ouvert : inventaire demandé")
	Events.inventory_requested.disconnect(cb)
	sim.new_game(SEED)
	check(not sim.state().vault_open and is_inf(GameState.chest_opened_at) and not GameState.base_inventory_unlocked, "nouvelle partie : tout est refermé")


func test_chest_view_frames() -> void:
	var sim := game()
	var v: ChestView = sim.world.chest_view
	check(v != null, "vue du coffre créée")
	check_eq(v.frame_at(3.0).y, 0, "fermé")
	GameState.chest_opened_at = 10.0
	check_eq(v.frame_at(9.9).y, 0, "fermé avant l'ouverture")
	check_eq(v.frame_at(10.6).y, 1, "ouverture")
	check_eq(v.frame_at(12.0).y, 2, "ouvert")
	check_eq(v.frame_at(10.0).x, 0, "première image de l'ouverture")


func test_wall_hint() -> void:
	var sim := game()
	var hint: VaultHint = sim.world.vault_hint
	check(hint != null, "glyphe créé")
	var e0 := hint.edge_x()
	check(e0 > 55.0 and e0 < 60.0, "glyphe au bord de la salle (%.2f)" % e0)
	var lines: Array[String] = []
	var cb := func(_u: Unit, text: String) -> void: lines.append(text)
	sim.engineer_spoke.connect(cb)
	var u := engineer()
	u.x = 52.0
	u.z = -146.0
	u.tx = u.x
	u.tz = u.z
	run(sim, 0.2)
	check(lines.is_empty(), "sans le Sceau : rien")
	GameState.mining_seal = true
	run(sim, 0.2)
	run(sim, 0.2)
	check_eq(lines.size(), 1, "réplique dite une fois")
	sim.world.dig_cell(14, -37)
	check(hint.edge_x() >= 60.0, "le glyphe suit le front de taille")
	sim.world.dig_cell(15, -37)
	hint._process(0.0)
	check(not hint.visible, "réserve découverte : glyphe éteint")
	sim.engineer_spoke.disconnect(cb)
	sim.new_game(SEED)
	check(not GameState.vault_hint_said, "nouvelle partie : réplique réarmée")
