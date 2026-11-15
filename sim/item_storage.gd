extends RefCounted
## Piles de 9 999 objets identiques par case. Le coffre débloqué est la destination exclusive.
const BASE_CAPACITY := 100
const MAX_STACK := 9999


static func character_available(u: Unit) -> bool:
	return u != null and u.alive() and u.role == "engineer" and u.unarmored and u.inventory_capacity > 0


static func store(items: Array[Dictionary], capacity: int, item: String) -> bool:
	# Compléter les piles existantes même si toutes les cases sont occupées.
	for stack: Dictionary in items:
		if stack["item"] == item and stack["quantity"] < MAX_STACK:
			stack["quantity"] += 1
			return true
	if items.size() < capacity:
		items.append({"item": item, "quantity": 1})
		return true
	return false


static func deposit(item: String, u: Unit, position: Vector2) -> void:
	if GameState.base_inventory_unlocked:
		if store(GameState.base_inventory, BASE_CAPACITY, item):
			return
	elif character_available(u):
		if store(u.inventory, u.inventory_capacity, item):
			return
	GameState.ground_items.append({"item": item, "position": position})
