extends "res://tests/fight_case.gd"
## Écart voulu D15 : lance-flammes à portée 12, tir continu (20 dégâts/s au niveau 1, dans un rayon de 2,2
## autour de la cible), aucune autre attaque (plus de sillon de feu), explosion de 45 dégâts à sa mort.


func _flamer() -> Unit:
	var u := setup("flammes", 1)
	u.job = null
	u.stance = "attack"
	u.tx = u.x
	u.tz = u.z
	return u


func test_continuous_fire_at_range_12() -> void:
	var u := _flamer()
	var e := foe("creep", u.x + 11.0, u.z, 400.0)
	var far := foe("creep", u.x + 11.0, u.z + 5.0, 400.0)
	var sim := game_sim()
	var alive: Array[Unit] = [u]
	var x0 := u.x
	for i in 60:
		sim.combat.update_units(1.0 / 60.0, alive)
		GameState.sim_time += 1.0 / 60.0
	check_near(e.hp, 380.0, 1e-6, "1 s de tir continu à 11 de distance : 20 dégâts")
	check_eq(far.hp, 400.0, "hors du rayon de brûlure : intact")
	check_eq(GameState.fire_walls.size(), 0, "aucun sillon de feu")
	check_eq(u.x, x0, "à portée : le porteur ne bouge pas")
	check(GameState.effects.filter(func(f: Dictionary) -> bool: return f["type"] == "laser").size() >= 15, "jet de flammes redessiné en continu")
	check(GameState.effects.filter(func(f: Dictionary) -> bool: return f["type"] == "laser").all(func(f: Dictionary) -> bool: return f.get("nozzle") == 1), "jet parti de la buse, tireur tourné vers la cible")


func test_out_of_range_walks_closer() -> void:
	var u := _flamer()
	foe("creep", u.x + 26.0, u.z, 400.0)
	var alive: Array[Unit] = [u]
	var x0 := u.x
	game_sim().combat.update_units(0.1, alive)
	check(u.x > x0, "au-delà de 24 : il s'approche")
	check_eq(GameState.enemies[0].hp, 400.0, "au-delà de 24 : aucun dégât")


func test_explodes_on_death() -> void:
	var u := _flamer()
	var near := foe("creep", u.x + 2.0, u.z, 100.0)
	var far := foe("creep", u.x + 5.0, u.z, 100.0)
	u.hp = 0.0
	game_sim().combat.finish_tick(1.0 / 60.0, [] as Array[Unit])
	check(u.dead, "le porteur est mort")
	check_eq(near.hp, 55.0, "ennemi à 2 : 45 dégâts")
	check_eq(far.hp, 100.0, "ennemi à 5 : hors de l'explosion")
	check(GameState.effects.any(func(f: Dictionary) -> bool: return f["type"] == "zone"), "onde de l'explosion")
	# Une seule explosion par mort.
	game_sim().combat.finish_tick(1.0 / 60.0, [] as Array[Unit])
	check_eq(near.hp, 55.0, "pas de seconde explosion")
