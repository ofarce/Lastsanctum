extends "res://tests/fight_case.gd"


func group_at(sim: Simulation, kinds: Array, center := Vector2(0, -120)) -> Array:
	var queue: Array = []
	for kind: String in kinds:
		queue.append({"at": GameState.sim_time, "x": 0.0, "kind": kind})
	sim.combat.tactics.plan(queue)
	var members: Array = []
	for entry: Dictionary in queue:
		var e := sim.combat.spawn_enemy(entry)
		e.x = center.x + (members.size() % 3 - 1) * 1.8
		e.z = center.y + (members.size() / 3) * 2.0
		members.append(e)
	members[0].tactical_group["anchor"] = center
	return members


func step_enemies(sim: Simulation, seconds: float, allies: Array[Unit] = []) -> void:
	for i in ceili(seconds / DT):
		GameState.sim_time += DT
		sim.combat.update_enemies(DT, allies)


func test_wave_plan_preserves_schedule_and_uses_small_groups() -> void:
	var sim := game()
	GameState.wave = 7
	sim.combat.start_wave()
	check_eq(GameState.spawn_queue.size(), 28, "effectif inchangé")
	for i in GameState.spawn_queue.size():
		var entry: Dictionary = GameState.spawn_queue[i]
		check_eq(entry["kind"], Combat.wave_kind(8, i, 28), "type inchangé")
		check_near(entry["at"], GameState.sim_time + 2.0, 1e-6, "escouades prêtes dès le lancement")
		check(entry.has("offset"), "place de départ dans la formation")
		check(int(entry["group"]["expected"]) <= 7, "petit groupe")
		check_eq(entry["group"]["id"], (i / 7) * 7, "groupe séquentiel")
	check_eq(sim.combat.tactics.role_for("strazhar"), "reserve", "champion en réserve")


func test_front_and_support_keep_order_during_march() -> void:
	var sim := game()
	GameState.units.clear()
	var members := group_at(sim, ["creep", "archer", "shield", "brute", "soldier", "spitter", "scout"])
	step_enemies(sim, 12.0)
	var shield: Enemy = members[2]
	var archer: Enemy = members[1]
	var spitter: Enemy = members[5]
	check(shield.z < archer.z and shield.z < spitter.z, "bouclier devant les tireurs")
	var min_z := INF
	var max_z := -INF
	for e: Enemy in members:
		min_z = minf(min_z, e.z)
		max_z = maxf(max_z, e.z)
		check(sim.state().walkable(e.x, e.z), "position praticable")
	check(max_z - min_z < 12.0, "groupe cohérent malgré les vitesses différentes")
	check(shield.z < -125, "le groupe progresse")


func test_early_contact_interrupts_gathering_and_target_stays_stable() -> void:
	var sim := game()
	var u := engineer()
	u.x = 0
	u.z = -124
	var members := group_at(sim, ["shield", "soldier", "archer"])
	members[0].tactical_group["release_at"] = GameState.sim_time + 30.0
	sim.combat.update_enemies(DT, [u] as Array[Unit])
	check_eq(members[0].tactical_group["phase"], "engage", "réaction avant le départ")
	var first: Unit = sim.combat.tactics.target(members[0], [u] as Array[Unit])
	var other := sim.spawn("autre", members[0].x, members[0].z, "paladin")
	check_eq(sim.combat.tactics.target(members[0], [u, other] as Array[Unit]), first, "cible verrouillée brièvement")
	u.hidden = true
	check_eq(sim.combat.tactics.target(members[0], [u, other] as Array[Unit]), other, "cible cachée abandonnée")


func test_reserve_waits_then_attacks_and_releases_if_front_dies() -> void:
	var sim := game()
	var u := engineer()
	u.x = 0
	u.z = -127
	var members := group_at(sim, ["shield", "soldier", "strazhar", "archer"])
	var champion: Enemy = members[2]
	sim.combat.update_enemies(DT, [u] as Array[Unit])
	check(champion.tactical_goal != null, "réserve en retrait")
	step_enemies(sim, 4.2, [u] as Array[Unit])
	check(champion.tactical_goal != null, "réserve toujours en retrait à quatre secondes")
	step_enemies(sim, 4.0, [u] as Array[Unit])
	check(champion.tactical_goal == null, "réserve libérée après huit secondes")
	members[0].hp = 0
	members[1].hp = 0
	sim.combat.update_enemies(DT, [u] as Array[Unit])
	check_eq(champion.tactical_group["phase"], "assault", "formation brisée après pertes")
	check(champion.tactical_goal == null, "survivant sans attente")


func test_ranged_retreat_is_bounded_and_then_fires() -> void:
	var sim := game()
	var u := engineer()
	u.x = 0
	u.z = -121
	u.hp = 10000
	var members := group_at(sim, ["archer", "shield", "soldier"])
	var archer: Enemy = members[0]
	for i in 240:
		u.x = archer.x
		u.z = archer.z - 1.0
		step_enemies(sim, DT, [u] as Array[Unit])
	check(archer.tactical_retreat <= 3.0 + DT, "repli borné")
	check(u.hp < 10000, "reprend le tir au lieu de fuir indéfiniment")


func test_column_crosses_gate_and_redeploys_without_rock() -> void:
	var sim := game()
	GameState.units.clear()
	var members := group_at(sim, ["shield", "soldier", "brute", "archer", "spitter", "creep", "scout"], Vector2(0, -76))
	members[0].tactical_group["release_at"] = GameState.sim_time
	for i in 65:
		step_enemies(sim, 1.0)
		for e: Enemy in members:
			check(sim.state().walkable(e.x, e.z), "aucun ennemi dans la roche")
	for e: Enemy in members:
		check(e.z < -100, "sortie du goulet")


func test_missing_members_and_no_defenders_cannot_block_wave() -> void:
	var sim := game()
	GameState.units.clear()
	var members := group_at(sim, ["shield", "archer", "creep"])
	GameState.enemies.erase(members[2])
	step_enemies(sim, 35.0)
	check(GameState.core_hp < 1.0, "les survivants atteignent et attaquent l'Ancre")


func test_new_game_clears_orders_and_portal_beasts_stay_independent() -> void:
	var sim := game()
	group_at(sim, ["shield", "archer"])
	sim.new_game(SEED)
	check(GameState.enemies.is_empty() and GameState.spawn_queue.is_empty(), "nouvelle partie sans anciens groupes")
	var beast := Enemy.make("beast", 0, -120, 0)
	GameState.enemies.append(beast)
	sim.combat.update_enemies(DT, [])
	check(beast.tactical_group.is_empty() and beast.tactical_goal == null, "rejeton indépendant")


func test_partial_spawn_waits_instead_of_counting_pending_units_as_dead() -> void:
	var sim := game()
	var queue: Array = []
	for i in 7:
		queue.append({"at": GameState.sim_time + i, "x": 0.0, "kind": "shield"})
	sim.combat.tactics.plan(queue)
	var e := sim.combat.spawn_enemy(queue[0])
	sim.combat.update_enemies(DT, [])
	check_eq(e.tactical_group["phase"], "gather", "les unités encore en file ne sont pas des pertes")
	step_enemies(sim, 11.0)
	check_eq(e.tactical_group["phase"], "march", "départ forcé après l'attente maximale")


func test_flank_requires_clear_route_and_reforms_after_contact() -> void:
	var sim := game()
	var u := engineer()
	u.x = 0
	u.z = -126
	var members := group_at(sim, ["shield", "scout", "soldier"], Vector2(0, -116))
	var scout: Enemy = members[1]
	scout.x = 0
	scout.z = -116
	sim.combat.update_enemies(DT, [u] as Array[Unit])
	check(scout.tactical_goal != null, "débordement en espace ouvert")
	if scout.tactical_goal != null:
		check(sim.world.pathfinder.clear_line(scout.pos(), scout.tactical_goal), "route latérale libre")
	u.hidden = true
	step_enemies(sim, 3.2, [u] as Array[Unit])
	check_eq(scout.tactical_group["phase"], "march", "reformation après disparition du contact")
	# Même manœuvre dans le tunnel : le détour sortirait dans la roche.
	u.hidden = false
	u.x = 5
	u.z = -92
	for e: Enemy in members:
		e.x = 5
		e.z = -84
	members[0].tactical_group["id"] = 7
	members[0].tactical_group["phase"] = "march"
	sim.combat.update_enemies(DT, [u] as Array[Unit])
	check(scout.tactical_goal == null, "pas de débordement à travers la paroi")


func test_slow_and_stun_apply_to_formation_and_reserve() -> void:
	var sim := game()
	GameState.units.clear()
	var members := group_at(sim, ["shield", "soldier", "strazhar"])
	var shield: Enemy = members[0]
	shield.stun = 1.0
	var start := shield.pos()
	step_enemies(sim, 0.5)
	check_eq(shield.pos(), start, "étourdissement respecté")
	shield.stun = 0
	shield.slow_until = GameState.sim_time + 2.0
	var before := shield.pos()
	step_enemies(sim, DT)
	check(shield.pos().distance_to(before) <= shield.speed * Catalog.SILLON["slow"] * DT + 0.00001, "ralentissement respecté")


func test_narrow_bent_gallery_uses_column_along_local_path() -> void:
	var sim := game()
	GameState.units.clear()
	# Galerie verticale de quatre unités, reliée à la salle par un coude vers l'ouest.
	for j in range(-35, -26):
		sim.state().dug[Vector2i(17, j)] = true
	for i in range(14, 18):
		sim.state().dug[Vector2i(i, -35)] = true
	sim.state().version += 1
	var members := group_at(sim, ["shield", "soldier", "archer", "spitter"], Vector2(69, -120))
	for i in members.size():
		members[i].x = 69
		members[i].z = -120 + i * 1.8
	members[0].tactical_group["release_at"] = GameState.sim_time
	sim.combat.update_enemies(DT, [])
	for e: Enemy in members:
		check(e.tactical_goal != null, "ordre de colonne")
		if e.tactical_goal != null:
			check_near(e.tactical_goal.x, 69.0, 0.1, "colonne alignée sur le chemin local")
			check(sim.state().walkable(e.tactical_goal.x, e.tactical_goal.y), "emplacement dans la galerie")
	check(members[0].tactical_goal.y < members[2].tactical_goal.y, "bouclier en tête de colonne")
