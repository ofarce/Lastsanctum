extends "res://tests/econ_case.gd"
const Storage := preload("res://sim/item_storage.gd")


func mine_one(sim: Simulation) -> void:
	var u := engineer()
	u.x = 55.4
	u.z = -136.3
	u.tx = u.x
	u.tz = u.z
	var cell: Dictionary = sim.state().diggable_cell(Vector2(58, -138))
	u.job = {"type": "dig", "cell": cell, "at": cell["at"], "work": 0.0}
	for i in range(4):
		sim.update_adepts(0.25)
	u.job = null


func test_mined_rock_routes_to_character_and_only_once() -> void:
	var sim := game()
	engineer().unarmored = true
	GameState.mining_seal = true
	mine_one(sim)
	check_eq(engineer().inventory, [{"item": "rock", "quantity": 1}], "une roche dans le paquetage")
	check(sim.state().dug.has(Vector2i(14, -35)), "bloc réellement miné")
	check(GameState.ground_items.is_empty(), "aucun doublon au sol")
	sim.update_adepts(1.0)
	check_eq(engineer().inventory.size(), 1, "pas de deuxième drop")


func test_locked_inventory_and_full_character_drop_on_ground() -> void:
	var sim := game()
	mine_one(sim)
	check_eq(engineer().inventory.size(), 0, "pas de paquetage avant perte armure")
	check_eq(GameState.ground_items.size(), 1, "reste au sol sans inventaire")
	check_eq(GameState.ground_items[0]["position"], Vector2(58, -138), "position du bloc")
	sim = game()
	engineer().unarmored = true
	GameState.mining_seal = true
	for i in range(10):
		engineer().inventory.append({"item": "rock", "quantity": Storage.MAX_STACK})
	mine_one(sim)
	check_eq(engineer().inventory.size(), 10, "paquetage plein inchangé")
	check_eq(GameState.ground_items.size(), 1, "reste au sol si plein")


func test_base_priority_and_full_base_never_falls_back() -> void:
	var sim := game()
	GameState.base_inventory_unlocked = true
	mine_one(sim)
	check_eq(GameState.base_inventory, [{"item": "rock", "quantity": 1}], "coffre prioritaire même sans paquetage")
	check(engineer().inventory.is_empty(), "paquetage vide")
	# Réseau des coffres infini (2026-11-22) : plus de coffre plein ni de repli au sol.
	sim.new_game(SEED)
	check(not GameState.base_inventory_unlocked, "déverrouillage réinitialisé")
	check(GameState.base_inventory.is_empty() and GameState.ground_items.is_empty(), "stock et sol réinitialisés")
	check(engineer().inventory.is_empty(), "nouveau personnage sans objets")


func test_definition_resistance_and_unknown_material() -> void:
	var sim := game()
	var definition := sim.state().block_definition(14, -35)
	check_eq(definition["material_name"], "Roche", "matière")
	check_eq(definition["drop_item"], "rock", "item")
	check_eq(definition["resistance"], 4, "résistance de la roche")
	var u := engineer()
	u.x = 55.4
	u.z = -136.3
	var cell: Dictionary = sim.state().diggable_cell(Vector2(58, -138))
	u.job = {"type": "dig", "cell": cell, "at": cell["at"], "work": 0.0}
	# Un coup de l'Ingénieur dure HIT_TIME / (ENGINEER_DIG × DIG_HITS) : trois coups et demi, puis le quatrième.
	var hit := TerrainState.HIT_TIME / (TerrainState.ENGINEER_DIG * TerrainState.DIG_HITS)
	sim.update_adepts(3.5 * hit)
	check(not sim.state().dug.has(Vector2i(14, -35)), "trois coups insuffisants")
	check(GameState.ground_items.is_empty(), "aucun drop avant destruction")
	sim.update_adepts(hit)
	check(sim.state().dug.has(Vector2i(14, -35)), "quatrième coup détruit")
	check_eq(GameState.ground_items[0]["item"], "rock", "item issu de la définition")
	sim.state().block_types[Vector2i(15, -35)] = "unknown"
	check(sim.state().dig_cell_at(15, -35, u.pos()) == null, "matière non enregistrée non minable")


func test_stack_limit_overflow_and_full_inventory_merging() -> void:
	game()
	var u := engineer()
	u.unarmored = true
	for i in range(9999):
		Storage.deposit("rock", u, Vector2.ZERO)
	check_eq(u.inventory, [{"item": "rock", "quantity": 9999}], "9999 objets dans une case")
	Storage.deposit("rock", u, Vector2.ZERO)
	check_eq(u.inventory[1], {"item": "rock", "quantity": 1}, "10000e objet dans une nouvelle pile")
	u.inventory_capacity = 2
	Storage.deposit("rock", u, Vector2.ZERO)
	check_eq(u.inventory[1]["quantity"], 2, "fusion même sans case libre")
	Storage.deposit("other_item", u, Vector2.ZERO)
	check_eq(GameState.ground_items.size(), 1, "objets différents non fusionnés")
	u.inventory[1]["quantity"] = 9999
	Storage.deposit("rock", u, Vector2.ZERO)
	check_eq(GameState.ground_items.size(), 2, "piles saturées : objet au sol")


func test_base_stacks_all_item_types_and_remains_exclusive() -> void:
	game()
	GameState.base_inventory_unlocked = true
	# Réseau des coffres infini (2026-11-22) : tout va au coffre, rien au sol.
	Storage.deposit("any_item", engineer(), Vector2.ZERO)
	check_eq(_count_of(GameState.base_inventory, "any_item"), 1, "au coffre")
	check(GameState.ground_items.is_empty(), "rien au sol")
	check(engineer().inventory.is_empty(), "pas de repli vers paquetage")


func _count_of(items: Array, item: String) -> int:
	var n := 0
	for st: Dictionary in items:
		if not st.is_empty() and st["item"] == item:
			n += int(st["quantity"])
	return n
