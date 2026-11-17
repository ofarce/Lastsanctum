extends RefCounted
## Piles de 9 999 objets identiques par case. Le coffre débloqué est la destination exclusive.
const PICKUP_RADIUS := 2.0
const BASE_CAPACITY := 100
const MAX_STACK := 9999


static func character_available(u: Unit) -> bool:
	return u != null and u.alive() and u.role == "engineer" and u.unarmored and u.inventory_capacity > 0


static func has_room(items: Array[Dictionary], capacity: int, item: String) -> bool:
	if items.size() < capacity:
		return true
	for stack: Dictionary in items:
		if stack.is_empty() or (stack["item"] == item and stack["quantity"] < MAX_STACK):
			return true
	return false


static func store(items: Array[Dictionary], capacity: int, item: String) -> bool:
	# Compléter les piles existantes même si toutes les cases sont occupées.
	for stack: Dictionary in items:
		if not stack.is_empty() and stack["item"] == item and stack["quantity"] < MAX_STACK:
			stack["quantity"] += 1
			return true
	for i in range(items.size()):
		if items[i].is_empty():
			items[i] = {"item": item, "quantity": 1}
			return true
	if items.size() < capacity:
		items.append({"item": item, "quantity": 1})
		return true
	return false


static func collect_nearby(u: Unit) -> void:
	if u.hidden or not character_available(u):
		return
	var position := u.pos()
	for i in range(GameState.ground_items.size() - 1, -1, -1):
		var drop := GameState.ground_items[i]
		if position.distance_squared_to(drop["position"]) <= PICKUP_RADIUS * PICKUP_RADIUS:
			if store(u.inventory, u.inventory_capacity, drop["item"]):
				GameState.ground_items.remove_at(i)


static func deposit(item: String, u: Unit, position: Vector2) -> void:
	if GameState.base_inventory_unlocked:
		if store(GameState.base_inventory, BASE_CAPACITY, item):
			return
	elif character_available(u):
		if store(u.inventory, u.inventory_capacity, item):
			return
	GameState.ground_items.append({"item": item, "position": position})


static func move_stack(source: Array[Dictionary], from: int, target: Array[Dictionary], to: int, capacity: int) -> void:
	if from < 0 or from >= source.size() or source[from].is_empty() or to < 0 or to >= capacity:
		return
	if is_same(source, target) and from == to:
		return
	while target.size() <= to:
		target.append({})
	var stack := source[from]
	if not target[to].is_empty() and target[to]["item"] == stack["item"]:
		var amount := mini(stack["quantity"], MAX_STACK - target[to]["quantity"])
		target[to]["quantity"] += amount
		stack["quantity"] -= amount
		if stack["quantity"] == 0:
			source[from] = {}
	else:
		source[from] = target[to]
		target[to] = stack


## Réserves où la fabrication et la caserne puisent : le coffre de base (s'il est débloqué), puis le sac de
## chaque Ingénieur vivant.
static func sources() -> Array:
	var out: Array = []
	if GameState.base_inventory_unlocked:
		out.append(GameState.base_inventory)
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive():
			out.append(u.inventory)
	return out


static func count(item: String) -> int:
	var n := 0
	for items: Array in sources():
		for stack: Dictionary in items:
			if not stack.is_empty() and stack["item"] == item:
				n += int(stack["quantity"])
	return n


static func has_all(cost: Dictionary) -> bool:
	for k: String in cost:
		if count(k) < int(cost[k]):
			return false
	return true


## Retire `cost` du stock, tout ou rien ; renvoie faux sans rien retirer s'il manque un objet.
static func take(cost: Dictionary) -> bool:
	if not has_all(cost):
		return false
	for k: String in cost:
		var left := int(cost[k])
		for items: Array in sources():
			for i in items.size():
				if left == 0:
					break
				var stack: Dictionary = items[i]
				if stack.is_empty() or stack["item"] != k:
					continue
				var n := mini(left, int(stack["quantity"]))
				stack["quantity"] -= n
				left -= n
				if stack["quantity"] <= 0:
					items[i] = {}
	return true


## Rend `cost` au stock (annulation) : coffre, sac de l'Ingénieur ou sol à `position`.
static func give(cost: Dictionary, position: Vector2) -> void:
	var engineer: Unit = null
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive():
			engineer = u
			break
	for k: String in cost:
		for i in int(cost[k]):
			deposit(k, engineer, position)


## Munitions (flèches, obus) : le stock habituel, puis les coffres rouges des bâtiments (un archer tire
## directement dans la production de l'Atelier sans attendre qu'on la rapporte).
static func ammo_sources() -> Array:
	var out := sources()
	for b: Building in GameState.buildings:
		out.append(b.output_box)
	return out


static func count_ammo(item: String) -> int:
	var n := 0
	for items: Array in ammo_sources():
		for stack: Dictionary in items:
			if not stack.is_empty() and stack["item"] == item:
				n += int(stack["quantity"])
	return n


## Retire une munition `item` ; faux s'il n'y en a nulle part.
static func take_ammo(item: String) -> bool:
	for items: Array in ammo_sources():
		for i in items.size():
			var stack: Dictionary = items[i]
			if stack.is_empty() or stack["item"] != item:
				continue
			stack["quantity"] -= 1
			if stack["quantity"] <= 0:
				items[i] = {}
			return true
	return false
