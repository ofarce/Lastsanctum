extends "res://tests/econ_case.gd"
## Bâtiments servis par des adeptes (sim/production.gd, règles du 2026-11-17) : postes et culte, vitesse, transports
## d'un coffre rouge vers un coffre bleu, mineurs d'un gisement inépuisable, Ingénieur au poste, recherche et Puits
## à l'arrêt sans personnel.

const Recipes := preload("res://data/recipes.gd")


func _select(units: Array) -> void:
	GameState.selected.clear()
	for u: Unit in units:
		GameState.selected.append(u)


func test_assign_respects_cult_and_five_posts() -> void:
	var sim := game()
	var b := built("forge", 26.0, -112.0)
	var wrong := sim.spawn("Adepte de Sigil", 20.0, -100.0, "sigil")
	_select([wrong])
	check(sim.order_staff(b), "clic droit traité")
	check(not Production.is_member(wrong, b), "un adepte de Sigil n'entre pas à la Fonderie")
	var adepts: Array[Unit] = []
	for i in 6:
		adepts.append(sim.spawn("Adepte d’Aether", 20.0 + i, -100.0, "aether"))
	_select(adepts)
	sim.order_staff(b)
	check_eq(Production.members(b, "worker").size(), Catalog.STAFF_MAX, "cinq postes au plus")
	check(not Production.is_member(adepts[5], b), "le sixième reste dehors")
	check(not sim.order_staff(built("sigil", -30.0, -112.0)), "un temple ne prend pas de poste")


func test_engineer_activates_but_never_carries() -> void:
	var sim := game()
	var b := built("forge", 26.0, -112.0)
	b.recipe = "copper_ingot"
	var u := engineer()
	_select([u])
	check(sim.order_staff(b), "l'Ingénieur prend un poste")
	run(sim, 8.0)
	check_eq(Production.at_post(b), 1, "Ingénieur au poste")
	# Du cuivre attend au coffre rouge d'un autre bâtiment : l'Ingénieur ne va pas le chercher.
	var other := built("workshop", -10.0, -112.0)
	Production.put_into(other.output_box, "copper", 10)
	run(sim, 10.0)
	check_eq(Production.count_in(other.output_box, "copper"), 10, "pas de transport par l'Ingénieur")
	Production.put_into(b.input_box, "copper", 5)
	run(sim, Recipes.craft_time(b.type) + 0.2)
	check_eq(Production.count_in(b.output_box, "copper_ingot"), 1, "la Fonderie tourne avec l'Ingénieur")


func test_adept_fetches_from_another_red_chest() -> void:
	var sim := game()
	var forge := built("forge", 26.0, -112.0)
	var creuset := built("creuset", -6.0, -112.0)
	Production.put_into(forge.output_box, "copper_ingot", 4)
	creuset.recipe = "copper_sword"
	var crew := staff(sim, creuset, 1)
	run(sim, 1.0)
	check_eq(String(crew[0].job.get("step")), "fetch", "l'adepte part chercher les lingots")
	check(Production.reserved({"kind": "building", "building": forge}, "copper_ingot") > 0, "lingots réservés")
	run(sim, 40.0)
	check_eq(Production.count_in(forge.output_box, "copper_ingot"), 0, "lingots pris au coffre rouge de la Fonderie")
	check_eq(Production.count_in(creuset.output_box, "copper_sword"), 2, "deux épées coulées")
	check(crew[0].carrying.is_empty(), "plus rien à porter")


func test_carried_items_are_not_lost() -> void:
	var sim := game()
	var forge := built("forge", 26.0, -112.0)
	var creuset := built("creuset", -6.0, -112.0)
	Production.put_into(forge.output_box, "copper_ingot", 2)
	creuset.recipe = "copper_sword"
	var crew := staff(sim, creuset, 1)
	for i in 600:
		sim.tick(DT)
		if not crew[0].carrying.is_empty():
			break
	check(not crew[0].carrying.is_empty(), "l'adepte porte les lingots")
	_select(crew)
	sim.issue_move(Vector2(crew[0].x, crew[0].z + 2.0))
	sim.tick(DT)
	check(crew[0].carrying.is_empty(), "nouvel ordre : il pose son lot")
	var total := 0
	for g: Dictionary in GameState.ground_items:
		if g["item"] == "copper_ingot":
			total += 1
	total += Simulation.ItemStorage.count("copper_ingot")
	check_eq(total, 2, "les deux lingots sont au stock ou au sol")


func test_miner_brings_batches_of_five() -> void:
	var sim := game()
	var st := sim.state()
	# Gisement inépuisable : une case d'un filon au sol.
	var key: Vector2i = st.lodes.keys()[0]
	# Sa clairière est dans une galerie pas encore découverte : on les ouvre toutes.
	st.open = st.mask.duplicate()
	st.found = st.count
	st.version += 1
	var cell: Variant = st.dig_cell_at(key.x, key.y, Vector2(key.x * 4 + 2, key.y * 4 + 6))
	check(cell != null, "gisement atteignable")
	var drop: String = st.block_definition(key.x, key.y)["drop_item"]
	var at: Vector2 = cell["at"]
	var b := built("forge", -6.0, -112.0)
	var warehouse := built("warehouse", at.x - 2.8, at.y - 5.8)
	staff(sim, warehouse)
	GameState.base_inventory_unlocked = true
	var crew := staff(sim, b, 1)
	crew[0].x = at.x
	crew[0].z = at.y
	_select(crew)
	check(sim.order_mining_cells([cell]), "ordre de minage")
	check(Production.is_member(crew[0], b, "miner"), "l'adepte devient mineur de la Fonderie")
	check_eq(Production.at_post(b), 0, "un mineur ne compte pas au poste")
	var seen_four := false
	for i in 60 * 30:
		sim.tick(DT)
		if int(crew[0].carrying.get("quantity", 0)) == 4:
			seen_four = true
			check_eq(Production.count_in(warehouse.output_box, drop), 0, "rien au coffre avant le cinquième bloc")
		if Production.count_in(warehouse.output_box, drop) > 0:
			break
	check(seen_four, "le lot grossit bloc par bloc")
	check_eq(Production.count_in(warehouse.output_box, drop), Catalog.MINE_BATCH, "un lot de 5 à l’entrepôt")
	check(crew[0].carrying.is_empty(), "mains vides après le dépôt")
	run(sim, 30.0)
	check_eq(Production.count_in(warehouse.output_box, drop) % Catalog.MINE_BATCH, 0, "toujours par lots de 5")


func test_warehouse_supply_distance_and_staff() -> void:
	var sim := game()
	GameState.base_inventory_unlocked = true
	GameState.base_inventory.append({"item": "wood", "quantity": 5})
	var warehouse := built("warehouse", -20.0, -112.0)
	var workshop := built("workshop", -10.0, -112.0)
	warehouse.output_box.append({"item": "wood", "quantity": 3})
	check_eq(Production.find_source(workshop, "wood").get("kind"), "vault", "entrepôt sans personnel")
	staff(sim, warehouse)
	check(Production.find_source(workshop, "wood").get("building") == warehouse, "bois disponible à proximité")
	workshop.x = CaveShape.CHEST_SPOT.x
	workshop.z = CaveShape.CHEST_SPOT.y - workshop.half()
	check_eq(Production.find_source(workshop, "wood").get("kind"), "vault", "coffre antique plus proche")


func test_research_and_soulwell_need_staff() -> void:
	var sim := game()
	give(1000.0)
	var lib := built("library", 26.0, -112.0)
	sim.start_research(lib, "minimap")
	run(sim, Catalog.RESEARCH_TIME + 0.5)
	check(not GameState.research_done.has("minimap"), "bibliothèque sans adepte : recherche figée")
	staff(sim, lib, 2)
	run(sim, Catalog.RESEARCH_TIME / 2.0 + 0.5)
	check(GameState.research_done.has("minimap"), "deux adeptes de Sigil : deux fois plus vite")
	var well := built("soulwell", -20.0, -112.0)
	var hurt := sim.spawn("Blessé", well.x, well.z + 6.0, "indra")
	hurt.hp = 10.0
	run(sim, 1.0)
	check_near(hurt.hp, 10.0, 1e-6, "Puits sans adepte : pas de soin")
	staff(sim, well, 1)
	run(sim, 1.0)
	check(hurt.hp > 10.0, "adepte de Medeina au poste : soin")


func test_warehouse_requests_from_panel() -> void:
	var sim := game()
	var b := built("warehouse", -6.0, -112.0)
	var workshop := built("workshop", 20.0, -112.0)
	var crew := staff(sim, b)
	Production.put_into(workshop.output_box, "wood", 12)
	Production.put_into(workshop.output_box, "iron", 4)
	GameState.anchor_selected = false
	GameState.selected.clear()
	GameState.hud_building = b
	var actions := HudModel.panel_actions(sim)
	var wood := actions.filter(func(a: Dictionary) -> bool: return a["id"] == "request-wood")
	check_eq(wood.size(), 1, "le panneau propose le bois")
	if wood.is_empty():
		return
	wood[0]["run"].call()
	run(sim, 24.0)
	check_eq(Production.count_in(b.output_box, "wood"), Production.WAREHOUSE_TARGET, "bois rapporté au coffre partagé")
	check_eq(Production.count_in(workshop.output_box, "iron"), 4, "fer laissé au producteur")
	Production.take_from(b.output_box, "wood", 2)
	run(sim, 24.0)
	check_eq(Production.count_in(b.output_box, "wood"), Production.WAREHOUSE_TARGET, "réassort après un retrait")
	wood[0]["run"].call()
	Production.take_from(b.output_box, "wood", 2)
	run(sim, 24.0)
	check_eq(Production.count_in(b.output_box, "wood"), Production.WAREHOUSE_TARGET - 2, "réassort désactivé")
	check(crew[0].carrying.is_empty(), "livraison terminée")
