extends "res://tests/fight_case.gd"
## Étape 8 (v2) : fin de partie et bannière. Seule l'Ancre détruite termine la partie ; l'Ingénieur tombé
## revient à la capsule (Simulation.engineer_fell).


func _ended_after(sim: Simulation) -> bool:
	var got := []
	var cb := func(won: bool) -> void: got.append(won)
	Events.game_over.connect(cb)
	sim.tick(DT)
	Events.game_over.disconnect(cb)
	return GameState.ended and got == [false]


func test_core_destroyed() -> void:
	var sim := game()
	GameState.core_hp = 0.0
	check(_ended_after(sim), "Ancre à 0 : défaite")
	var hud: Hud = _main.get_node("Hud")
	check_eq(hud._banner_title.text, "L’ANCRE EST PERDUE", "bannière")


func test_engineer_dies() -> void:
	var sim := game()
	sim.spawn("Adepte archer", 0.0, -120.0, "archer")
	# Seule la destruction de l'Ancre termine la partie : l'Ingénieur tombé revient à la capsule.
	var u := engineer()
	u.hp = 0.0
	check(not _ended_after(sim), "Ingénieur tombé : la partie continue")
	check(GameState.engineer_respawn_at < INF, "retour à la capsule programmé")
	GameState.sim_time = GameState.engineer_respawn_at
	sim.tick(DT)
	check(u.alive() and u.hp == u.max_hp, "il revient avec tous ses PV")


func test_no_ally_left() -> void:
	var sim := game()
	for u in GameState.units:
		u.hp = 0.0
	check(not _ended_after(sim), "plus aucun allié : la partie continue tant que l'Ancre tient")


func test_simulation_frozen_after_end() -> void:
	var sim := game()
	GameState.core_hp = 0.0
	sim.tick(DT)
	var u := engineer()
	u.tx = u.x + 10.0
	var x := u.x
	run(sim, 1.0)
	check_eq(u.x, x, "plus rien ne bouge")


func test_enemy_damage_with_guard_shield_and_armor() -> void:
	var u := setup("lame", 3)
	var e := foe("brute", 0.5, -120.0, 100.0)
	e.damage = 12.0
	e.cooldown = 0.0
	u.shield = 1.0
	var hp := u.hp
	var alive: Array[Unit] = [u]
	# L'ennemi arme son coup (Catalog.ENEMY_WINDUP) avant de frapper : on avance jusqu'au premier coup porté.
	for i in 200:
		GameState.sim_time += 0.02
		game_sim().combat.update_enemies(0.02, alive)
		if u.hp < hp:
			break
	check_near(hp - u.hp, maxf(12.0 * 0.35 * 0.55 * 0.15, 12.0 * 0.35 * 0.55 - 2.0), 1e-9, "bouclier ×0,35, garde ×0,55, défense −2")
