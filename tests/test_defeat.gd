extends "res://tests/fight_case.gd"
## Étape 8 (v2) : fin de partie (Ancre détruite, plus aucun allié, Ingénieur tombé) et bannières.


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
	engineer().hp = 0.0
	check(_ended_after(sim), "Ingénieur tombé : défaite")
	var hud: Hud = _main.get_node("Hud")
	check_eq(hud._banner_title.text, "L’INGÉNIEUR EST TOMBÉ", "bannière")


func test_no_ally_left() -> void:
	var sim := game()
	for u in GameState.units:
		u.hp = 0.0
	check(_ended_after(sim), "plus aucun allié : défaite")


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
	game_sim().combat.update_enemies(0.01, alive)
	check_near(hp - u.hp, maxf(12.0 * 0.35 * 0.55 * 0.15, 12.0 * 0.35 * 0.55 - 2.0), 1e-9, "bouclier ×0,35, garde ×0,55, défense −2")
