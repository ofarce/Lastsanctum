extends "res://tests/econ_case.gd"

const Inventory := preload("res://ui/inventory/engineer_inventory.gd")
const Storage := preload("res://sim/item_storage.gd")


func test_batches_transport_and_inventory() -> void:
	var sim := game()
	var archerie := built("archerie", 26.0, -112.0)
	staff(sim, archerie, 1)
	archerie.recipe = "arrows"
	Production.put_into(archerie.input_box, "wood", 1)
	run(sim, 10.0)
	check_eq(Production.count_in(archerie.output_box, "arrows"), 3, "un bois produit 3 flèches")
	archerie.input_box.clear()
	Production.put_into(archerie.input_box, "wood", 1)
	archerie.output_box.clear()
	# Réseau des coffres infini (2026-11-22) : plus de stock plein, ce cas a disparu.
	var workshop := built("workshop", 10.0, -126.0)
	# Plus de transport (réseau des coffres, 2026-11-22) : le bâtiment puise directement dans le réseau.
	var inventory := Inventory.new()
	_main.add_child(inventory)
	var u := engineer()
	u.unarmored = true
	u.inventory.clear()
	u.inventory.append({"item": "wood", "quantity": 12})
	Events.production_chest_requested.emit(workshop, "in", u)
	check(inventory.opened, "le coffre ouvre le réseau")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = inventory._origin + Vector2(-10, -10) * inventory._scale
	inventory._input(click)
	check(not inventory.opened, "clic sur le fond ferme le coffre")
	Events.inventory_requested.emit()
	inventory._input(click)
	check(not inventory.opened, "clic sur le fond ferme aussi l'inventaire")
	inventory.free()
