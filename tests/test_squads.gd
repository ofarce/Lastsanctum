extends "res://tests/econ_case.gd"


func squad(sim: Simulation) -> Array[Unit]:
	var barracks := built("caserne", 26, -112)
	sim.spawn_trained(barracks, "archer")
	var result: Array[Unit] = []
	result.assign(GameState.units.slice(-4))
	return result


func kill(sim: Simulation, u: Unit) -> void:
	u.hp = 0
	sim.on_unit_death(u)


func test_four_members_unique_squads_and_indivisible_orders() -> void:
	var sim := game()
	var first := squad(sim)
	var second := squad(sim)
	check_eq(first.size(), 4)
	check(first[0].squad != second[0].squad, "identifiants distincts")
	for u: Unit in first:
		check_eq(u.squad, first[0].squad)
		check_eq(u.squad_capacity, 4)
	GameState.selected.assign([first[1]])
	sim.issue_move(Vector2(0, -125))
	for u: Unit in first:
		check(u.force_move, "ordre appliqué à toute l’escouade")
	for u: Unit in second:
		check(not u.force_move, "autre escouade intacte")
	sim.hold()
	for u: Unit in first:
		check_eq(u.stance, "hold", "position pour toute l’escouade")


func test_click_and_box_select_whole_squad() -> void:
	var sim := game()
	var members := squad(sim)
	var input: InputController = _main.get_node("Input")
	var p := input.project(members[0].x, 1.0, members[0].z)
	input._left_click(p, false)
	check_eq(GameState.selected.size(), 4, "clic sélectionne quatre")
	GameState.selected.clear()
	input.set("_box_from", p - Vector2.ONE)
	input.set("_box_to", p + Vector2.ONE)
	input._box_select(false)
	check_eq(GameState.selected.size(), 4, "rectangle sur un membre sélectionne quatre")


func test_losses_revive_at_well_and_rejoin_moving_survivors() -> void:
	var sim := game()
	var members := squad(sim)
	var well := built("soulwell", -30, -104)
	staff(sim, well, 1)
	members[1].level = 2
	members[2].level = 3
	members[1].xp = 17
	kill(sim, members[1])
	kill(sim, members[2])
	check_eq(Simulation.squad_revive_cost(members[0]), {"vie": 500}, "coût individuel × niveaux cumulés")
	GameState.selected = Simulation.squad_survivors(members[0])
	GameState.res["vie"] = 499
	var action: Dictionary = HudModel.panel_actions(sim).filter(func(a: Dictionary) -> bool: return a["id"] == "revive-squad")[0]
	check(action["disabled"], "fonds insuffisants")
	check(action["label"].contains("500 Vie"), "coût affiché")
	sim.revive_squad(members[0])
	check_eq(GameState.res["vie"], 499, "aucun paiement partiel")
	GameState.res["vie"] = 500
	var input: InputController = _main.get_node("Input")
	check(input.hud_key("r"), "raccourci R de résurrection")
	check_eq(GameState.res["vie"], 0, "coût exact")
	check_eq(Simulation.squad_survivors(members[0]).size(), 4)
	check_eq(GameState.selected.size(), 4, "renforts ajoutés à sélection")
	check_near(members[1].x, well.x, 0.001, "apparition au Puits")
	check(members[1].z > well.z, "devant le Puits")
	check(members[1].rejoining and members[1].force_move, "ralliement actif")
	check_eq(members[1].level, 2)
	check_eq(members[1].xp, 17.0)
	members[0].x = 0
	sim.update_squads()
	check(absf(members[1].tx) < 2, "cible suit survivant en mouvement")
	check(Simulation.squad_losses(members[0]).is_empty(), "pertes comblées")
	check(not HudModel.panel_actions(sim).any(func(a: Dictionary) -> bool: return a["id"] == "revive-squad"), "capacité disparaît à effectif plein")
	check_eq(GameState.menace, 4, "résurrection ne recrute pas")


func test_wiped_squad_cannot_revive_and_other_squad_unaffected() -> void:
	var sim := game()
	var members := squad(sim)
	var other := squad(sim)
	var well := built("soulwell", -30, -104)
	staff(sim, well, 1)
	kill(sim, other[1])
	for u: Unit in members:
		kill(sim, u)
	check_eq(GameState.fallen.size(), 1, "pertes escouade anéantie retirées")
	check(GameState.fallen.has(other[1]), "autre escouade conservée")
	give(1000)
	sim.revive_unit(well, members[0])
	sim.revive_squad(members[0])
	check_eq(GameState.res["vie"], 1000.0, "aucun paiement pour unité anéantie")
	check(Simulation.squad_survivors(members[0]).is_empty(), "aucune résurrection")


func test_well_button_revives_member_and_shortcut_requires_well() -> void:
	var sim := game()
	var members := squad(sim)
	kill(sim, members[1])
	GameState.selected.assign([members[0]])
	give(500)
	var action: Dictionary = HudModel.panel_actions(sim).filter(func(a: Dictionary) -> bool: return a["id"] == "revive-squad")[0]
	check(action["disabled"], "Puits nécessaire")
	var well := built("soulwell", -30, -104)
	staff(sim, well, 1)
	GameState.selected.clear()
	GameState.hud_building = well
	var revive: Dictionary = HudModel.panel_actions(sim).filter(func(a: Dictionary) -> bool: return a["id"].begins_with("revive-"))[0]
	revive["run"].call()
	check(members[1].alive() and members[1].rejoining, "résurrection au Puits rallie aussi")
	check_eq(members[1].squad, members[0].squad, "identité conservée")


func test_squad_has_no_upkeep() -> void:
	var sim := game()
	var members := squad(sim)
	give(10)
	sim.tick(0.5)
	for resource in ["vie", "discipline"]:
		check_eq(GameState.res[resource], 10.0)
		check_eq(Simulation.resource_rates()[resource], 0)
	kill(sim, members[0])
	sim.tick(1.0)
	for resource in ["vie", "discipline"]:
		check_eq(GameState.res[resource], 10.0)
		check_eq(Simulation.resource_rates()[resource], 0)
