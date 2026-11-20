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
	check_eq(Production.count_in(archerie.output_box, "arrows"), 15, "un bois produit 15 flèches")
	archerie.input_box.clear()
	Production.put_into(archerie.input_box, "wood", 1)
	archerie.output_box.clear()
	for i in Production.BOX_CAPACITY:
		archerie.output_box.append({"item": "arrows" if i == 0 else "filler%d" % i, "quantity": Storage.MAX_STACK - 14 if i == 0 else Storage.MAX_STACK})
	check_eq(Production.craft_workers(archerie), 0, "le lot entier doit tenir dans le coffre")
	var workshop := built("workshop", 10.0, -126.0)
	var crew := staff(sim, workshop, 1)
	var forge := built("forge", -6.0, -112.0)
	Production.put_into(forge.output_box, "wood", 20)
	workshop.recipe = "barricade"
	var production := Production.new(sim)
	production._dispatch(workshop)
	check_eq(crew[0].job["fetch"]["qty"], 5, "transport limité à cinq ressources")
	var pos := Production.src_pos(crew[0].job["fetch"]["src"])
	crew[0].x = pos.x
	crew[0].z = pos.y
	production.update_unit(crew[0], DT)
	check_eq(crew[0].carrying.get("quantity"), 5, "cinq ressources prises à la source")
	var inventory := Inventory.new()
	_main.add_child(inventory)
	var u := engineer()
	u.unarmored = true
	u.inventory.clear()
	u.inventory.append({"item": "wood", "quantity": 12})
	Events.production_chest_requested.emit(workshop, "in", u)
	var source := {"items": u.inventory, "index": 0, "capacity": u.inventory_capacity}
	inventory._drop(source, {"box": 0})
	check(u.inventory[0].is_empty(), "pile retirée du sac")
	check_eq(Production.count_in(workshop.input_box, "wood"), 13, "pile fusionnée dans le coffre bleu")
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
