extends "res://tests/fight_case.gd"
## Chaque tir d'archer prend une flèche à la réserve globale ; sans flèche, l'archer ne tire pas.
const Storage := preload("res://sim/item_storage.gd")


func _archer() -> Unit:
	var u := setup("archer", 1)
	u.job = null
	u.stance = "attack"
	return u


func _give_arrows(n: int) -> void:
	GameState.base_inventory_unlocked = true
	for i in n:
		Storage.store(GameState.base_inventory, Storage.BASE_CAPACITY, "arrows")


func test_shot_consumes_one_arrow() -> void:
	var u := _archer()
	_give_arrows(2)
	var n0 := Storage.count("arrows")
	var e := foe("creep", u.x + 20.0, u.z, 400.0)
	game_sim().combat.barracks_strike(u, e)
	check_eq(Storage.count("arrows"), n0 - 1, "un tir : une flèche en moins")
	check(e.hp < 400.0, "la flèche touche")
	# Le chiffre de dégâts naît à l'arrivée de la flèche, pas au départ.
	var nums := GameState.damage_numbers.filter(func(d: Dictionary) -> bool: return d["target"] == e)
	check(not nums.is_empty() and nums[0]["age"] < 0.0, "chiffre de dégâts masqué jusqu'à l'impact")


func test_no_arrow_no_shot() -> void:
	var u := _archer()
	var have := Storage.count("arrows")
	if have > 0:
		Storage.take({"arrows": have})
	var e := foe("creep", u.x + 20.0, u.z, 400.0)
	game_sim().combat.barracks_strike(u, e)
	check_eq(e.hp, 400.0, "sans flèche : pas de tir")
	check(GameState.effects.filter(func(f: Dictionary) -> bool: return f["type"] == "arrow").is_empty(), "aucune flèche tirée")
