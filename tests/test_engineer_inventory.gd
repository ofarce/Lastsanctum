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


func test_mining_slot_follows_actual_research() -> void:
	var sim := game()
	check_eq(Inventory.mining_item(), "", "emplacement vide avant recherche")
	for id: String in ["mining_concept", "mining_spark", "mining_power"]:
		GameState.research_done[id] = true
	check_eq(Inventory.mining_item(), "", "prérequis seuls insuffisants")
	give(100.0)
	var forge := built("forge", 0, -130)
	sim.start_research(forge, "mining_artifact")
	sim.update_research(9.0)
	check_eq(Inventory.mining_item(), "", "recherche en cours")
	sim.update_research(1.0)
	check_eq(Inventory.mining_item(), "Sceau de minage", "sceau automatiquement équipé")
	sim.new_game(SEED)
	check_eq(Inventory.mining_item(), "", "sceau réinitialisé")
