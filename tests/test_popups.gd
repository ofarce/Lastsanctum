extends "res://tests/fight_case.gd"
## Textes flottants : chiffres de dégâts (blancs) et « Nouvelle ressource : … ! » (jaune).

const Blocks := preload("res://data/mineable_blocks.gd")


func test_damage_number_on_hit() -> void:
	var u := setup("engineer", 1)
	var sim := game_sim()
	var e := foe("creep", 2.0, -120.0, 100.0)
	GameState.damage_numbers.clear()
	sim.combat.damage(e, 10.0, u)
	check_eq(GameState.damage_numbers.size(), 1, "un chiffre par coup")
	check(GameState.damage_numbers[0]["target"] == e, "chiffre attaché à la cible")
	check(GameState.damage_numbers[0]["amount"] > 0.0, "valeur positive")
	var first: float = GameState.damage_numbers[0]["amount"]
	sim.combat.damage(e, 10.0, u)
	check_eq(GameState.damage_numbers.size(), 1, "coups rapprochés cumulés")
	check_eq(GameState.damage_numbers[0]["amount"], first * 2.0, "cumul des dégâts")
	GameState.damage_numbers[0]["age"] = 0.5
	sim.combat.damage(u, 5.0)
	check_eq(GameState.damage_numbers.size(), 2, "allié blessé : son propre chiffre")
	sim.combat.damage(e, 0.0, u)
	check_eq(GameState.damage_numbers.size(), 2, "pas de chiffre pour 0 dégât")


func test_new_resource_once() -> void:
	var u := setup("engineer", 1)
	var sim := game_sim()
	GameState.collected_items.clear()
	var item: String = Blocks.ITEMS.keys()[0]
	sim._collect_mined_item(item, u, u.pos())
	sim._collect_mined_item(item, u, u.pos())
	var news := GameState.effects.filter(func(fx: Dictionary) -> bool: return fx["type"] == "new_resource")
	check_eq(news.size(), 1, "annoncée une seule fois")
	check_eq(news[0]["item"], item, "bonne ressource")
	check(news[0]["miner"] == u, "au-dessus du récolteur")
