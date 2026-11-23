extends "res://tests/econ_case.gd"

const Inventory := preload("res://ui/inventory/engineer_inventory.gd")


func test_right_click_and_item_tooltips() -> void:
	game()
	var u := engineer()
	u.unarmored = true
	u.inventory = [{"item": "iron_sword", "quantity": 2}, {"item": "wood", "quantity": 5}]
	var inventory := Inventory.new()
	_main.add_child(inventory)
	Events.inventory_requested.emit()
	var point := inventory._origin + Vector2(297, 756) * inventory._scale
	var tooltip := inventory._get_tooltip(point)
	check(tooltip.contains("Épée à une main en fer") and tooltip.contains("Dégâts : 10"), "nom et dégâts au survol")
	check(tooltip.contains("Portée (unités) : 6") and tooltip.contains("Recharge (s) : 0.67"), "portée et recharge au survol")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = point
	inventory._input(click)
	# L'Exilé n'équipe plus que des mods (2026-11-21) : l'épée, réservée aux adeptes, reste au paquetage.
	check(u.equipment.get("Main droite") != "iron_sword", "clic droit n'équipe pas l'épée")
	check_eq(u.inventory[0]["quantity"], 2, "les deux épées restent au paquetage")
	click.pressed = false
	inventory._input(click)
	click.pressed = true
	click.position = inventory._origin + Vector2(362, 756) * inventory._scale
	inventory._input(click)
	check_eq(u.inventory[1]["quantity"], 5, "ressource non équipable conservée")
	check(inventory._get_tooltip(click.position).contains("Bois"), "nom de la ressource")
	click.position = inventory._origin - Vector2(10, 10)
	inventory._input(click)
	check(not inventory.opened, "clic droit extérieur ferme")
	check(inventory._consume_right_release, "relâchement réservé à l'inventaire")
	click.pressed = false
	inventory._input(click)
	check(not inventory._consume_right_release, "relâchement absorbé")
	inventory.free()
