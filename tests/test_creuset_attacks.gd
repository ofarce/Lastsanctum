extends "res://tests/econ_case.gd"
## Attaques des armes du Creuset (planches/armes-attaques.html) : taille d'épée en arc à 1,5 bloc devant l'Ingénieur,
## balle de l'Arbalestrie (ancien canon) arrêtée par le premier obstacle, animations d'attaque du Tyrien.

const Storage := preload("res://sim/item_storage.gd")
const Gear := preload("res://data/gear_items.gd")
const Ammo := preload("res://data/ammo.gd")


func _armed(item: String, slot := "Main droite") -> Unit:
	var u := engineer()
	u.unarmored = true
	# L'Exilé n'équipe plus que des mods (2026-11-21) : l'arme est posée directement pour éprouver ses attaques.
	u.equipment[slot] = item
	if Gear.two_handed(u):
		u.equipment.erase("Main gauche")
	return u


func _dummy(x: float, z: float) -> Enemy:
	var e := Enemy.make("brute", x, z, 1.0)
	e.hp = 500.0
	e.max_hp = 500.0
	GameState.enemies.append(e)
	return e


func test_sword_slash_hits_front_arc_at_one_and_a_half_blocks() -> void:
	var sim := game()
	var u := _armed("iron_sword")
	check_near(Catalog.unit_reach(u), 6.0, 1e-9, "portée de la taille : 1,5 bloc")
	var front := _dummy(u.x + 5.0, u.z)
	var side := _dummy(u.x + 3.0, u.z + 2.0)
	var behind := _dummy(u.x - 5.0, u.z)
	var far := _dummy(u.x + 8.0, u.z)
	sim.combat.aimed_attack(u, Vector2(u.x + 5.0, u.z))
	check(front.hp < 500.0, "ennemi devant, à 1,25 bloc : touché")
	check(side.hp < 500.0, "ennemi sur le côté de l'arc : touché")
	check_eq(behind.hp, 500.0, "ennemi derrière : épargné")
	check_eq(far.hp, 500.0, "ennemi au-delà de 1,5 bloc : épargné")
	check_near(u.attack, 0.67, 1e-6, "attaque 50 % plus rapide")
	check(GameState.effects.any(func(e: Dictionary) -> bool: return e["type"] == "slash" and not e["two"]), "arc blanc de la taille")


func test_greatsword_slash_is_two_handed_arc() -> void:
	var sim := game()
	var u := _armed("copper_greatsword")
	sim.combat.aimed_attack(u, Vector2(u.x, u.z + 5.0))
	check(GameState.effects.any(func(e: Dictionary) -> bool: return e["type"] == "slash" and e["two"]), "arc en diagonale à deux mains")
	check_near(u.attack, 0.89, 1e-6, "recharge des épées à deux mains")


func test_cannon_ball_stops_at_first_enemy() -> void:
	var sim := game()
	var u := _armed("cannon")
	# Arbalestrie : chaque tir coûte de la mana (data/ammo.gd), plus de munition de fer.
	give(100.0)
	var first := _dummy(u.x + 5.0, u.z)
	var second := _dummy(u.x + 9.0, u.z)
	sim.combat.aimed_attack(u, Vector2(u.x + 20.0, u.z))
	check(first.hp < 500.0, "la balle touche le premier ennemi")
	check_eq(second.hp, 500.0, "et s'y arrête")
	var nums := GameState.damage_numbers.filter(func(d: Dictionary) -> bool: return d["target"] == first)
	check(nums.size() == 1 and nums[0]["age"] < 0.0, "chiffre de dégâts masqué jusqu'à l'arrivée de la balle")
	var cd: float = Gear.ITEMS["cannon"]["cd"] * float(Ammo.AMMO[Ammo.current()].get("cd_mult", 1.0))
	check_near(u.attack, cd, 1e-6, "cadence de l'arme et de la munition")
	check_near(GameState.res["forge"], 100.0, 1e-6, "le tir ne coûte pas de mana")
	var ball: Array = GameState.effects.filter(func(e: Dictionary) -> bool: return e["type"] == "cball")
	check_eq(ball.size(), 1, "une balle tirée")
	# La balle s'arrête au bord de la silhouette (Enemy.BODY), devant le centre de l'ennemi.
	var tx := float(ball[0]["tx"])
	check(tx > u.x + 1.0 and tx <= first.x + 0.01, "arrêtée sur l'ennemi (%.2f)" % tx)


func test_tyrien_attack_animations_exported() -> void:
	TyrienArt.load_all()
	for anim: String in ["slash1", "slash2", "shoot"]:
		check(TyrienArt.meta["anims"].has(anim), "animation " + anim)
	for item: String in ["copper_sword", "iron_sword", "copper_greatsword", "iron_greatsword", "cannon", "copper_shield", "iron_shield"]:
		check(TyrienArt.weapon_icon(item) != null, "icône de " + item)
		check(TyrienArt.frames.has(Gear.ITEMS[item]["piece"]), "calque porté de " + item)
