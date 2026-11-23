extends "res://tests/econ_case.gd"

const Inventory := preload("res://ui/inventory/engineer_inventory.gd")


func test_shortcut_unlock_close_and_reset() -> void:
	var sim := game()
	var inventory := Inventory.new()
	_main.add_child(inventory)
	var key := InputEventKey.new()
	key.keycode = KEY_C
	key.pressed = true
	inventory._input(key)
	check(not inventory.opened, "C inactif avec armure")
	engineer().unarmored = true
	inventory._input(key)
	check(inventory.opened and inventory.visible, "C ouvre après rupture")
	key.echo = true
	inventory._input(key)
	check(inventory.opened, "répétition ignorée")
	key.echo = false
	key.keycode = KEY_ESCAPE
	inventory._input(key)
	check(not inventory.opened, "Échap ferme")
	key.keycode = KEY_C
	inventory._input(key)
	inventory._input(key)
	check(not inventory.opened, "C ferme aussi")
	inventory._input(key)
	sim.new_game(SEED)
	check(not inventory.opened and not Inventory.available(), "nouvelle partie reverrouille")
	inventory.free()


func test_mining_slot_follows_capsule_gift() -> void:
	var sim := game()
	check_eq(Inventory.mining_item(), "", "emplacement vide avant le Coffre Antique")
	GameState.mining_seal = true
	check_eq(Inventory.mining_item(), "Sceau de minage", "sceau automatiquement équipé")
	sim.new_game(SEED)
	check_eq(Inventory.mining_item(), "", "sceau réinitialisé")


func test_right_click_and_withdraw_from_production_chests() -> void:
	var sim := game()
	var b := built("forge", 0, -130)
	var input: InputController = sim.get_node("../Input")
	var inventory := Inventory.new()
	_main.add_child(inventory)
	var u := engineer()
	u.unarmored = true
	GameState.selected = [u]
	GameState.base_inventory_unlocked = true
	# Réseau des coffres (2026-11-22) : chaque coffre de bâtiment ouvre le même stockage global, sans case pleine.
	for kind: String in ["in", "out"]:
		var pos := Production.chest_pos(b, kind)
		u.x = pos.x
		u.z = pos.y + 1
		sim.world.fog.refresh(sim.state())
		input._right_click(input.project(pos.x, 0, pos.y))
		run(sim, DT)
		check(inventory.opened, "clic droit sur le coffre : réseau ouvert (%s)" % kind)
		inventory.close()
	inventory.free()


func test_ground_pickup_uses_personal_inventory() -> void:
	var sim := game()
	var u := engineer()
	u.unarmored = true
	u.inventory_capacity = 1
	GameState.base_inventory_unlocked = true
	GameState.ground_items.append({"item": "rock", "position": u.pos() + Vector2.RIGHT})
	GameState.ground_items.append({"item": "wood", "position": u.pos() + Vector2.RIGHT * 8})
	sim.tick(DT)
	check_eq(u.inventory, [{"item": "rock", "quantity": 1}], "ressource proche dans le sac")
	check_eq(GameState.ground_items.size(), 1, "ressource éloignée encore au sol")
	u.x += 8
	sim.tick(DT)
	check_eq(GameState.ground_items.size(), 1, "sac plein : ressource conservée")
	u.inventory.clear()
	sim.tick(DT)
	check_eq(u.inventory, [{"item": "wood", "quantity": 1}], "ramassage quand une case se libère")
	check(GameState.ground_items.is_empty() and GameState.base_inventory.is_empty(), "transfert terminé")
