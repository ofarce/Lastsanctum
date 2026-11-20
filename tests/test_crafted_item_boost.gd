extends "res://tests/econ_case.gd"


func test_button_adds_all_recipes_to_stock() -> void:
	game()
	var hud: Hud = _main.get_node("Hud")
	var button: Button = hud.get("_crafted_item_boost")
	var construction: Button = hud.get("_fast_construction")
	check_eq(button.position.x, 16.0, "bouton à gauche")
	check(button.position.y >= construction.position.y + construction.size.y, "sous les boutons existants")
	GameState.base_inventory.clear()
	GameState.base_inventory_unlocked = false
	for click in 2:
		button.pressed.emit()
		check(GameState.base_inventory_unlocked, "stock accessible")
		for station: String in ["workshop", "scierie", "archerie", "forge", "creuset"]:
			for item: String in Simulation.Recipes.RECIPES[station]:
				check_eq(Production.count_in(GameState.base_inventory, item), 100 * (click + 1), item + " ajouté au stock")
	GameState.base_inventory.clear()
	for i in Simulation.ItemStorage.BASE_CAPACITY:
		GameState.base_inventory.append({"item": "full%d" % i, "quantity": Simulation.ItemStorage.MAX_STACK})
	GameState.base_inventory[0] = {"item": "torch", "quantity": 10}
	var before := GameState.base_inventory.duplicate(true)
	button.pressed.emit()
	check_eq(GameState.base_inventory, before, "stock plein : aucun ajout partiel")
