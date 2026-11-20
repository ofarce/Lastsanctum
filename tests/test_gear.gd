extends "res://tests/econ_case.gd"
## Équipement visible de l'Ingénieur sans armure (tenue tyrienne) : emplacements, calques empilés, visée.

const Gear := preload("res://data/gear_items.gd")
const Inventory := preload("res://ui/inventory/engineer_inventory.gd")


func test_every_piece_has_layers_for_every_animation() -> void:
	TyrienArt.load_all()
	for item: String in Gear.ITEMS:
		var piece: String = Gear.ITEMS[item]["piece"]
		check(TyrienArt.frames.has(piece), "calque %s exporté" % piece)
		check_eq(TyrienArt.slot_of(piece), Gear.slot_of(item), "emplacement de %s" % item)
		for anim: String in TyrienArt.ANIMS:
			check_eq(TyrienArt.frames[piece][anim].size(), TyrienArt.frames["base"][anim].size(), "%s · %s" % [piece, anim])
	check_eq(EngineerAim.frames_bare.size() if not EngineerAim.frames_bare.is_empty() else 4, 4, "4 lignes de visée")


func test_equip_swap_and_unequip() -> void:
	game()
	var u := engineer()
	u.unarmored = true
	u.inventory.assign([{"item": "gear_iron", "quantity": 1}, {"item": "gear_mail", "quantity": 1}, {"item": "gear_helm", "quantity": 1}])
	check(not Gear.equip(u, u.inventory, 2, "Torse"), "casque refusé sur le torse")
	check(Gear.equip(u, u.inventory, 0, "Torse"), "plastron équipé")
	check_eq(u.equipment.get("Torse", ""), "gear_iron", "porté")
	check(u.inventory[0].is_empty(), "case vidée")
	check(Gear.equip(u, u.inventory, 1, "Torse"), "cotte à la place")
	check_eq(u.inventory[1].get("item", ""), "gear_iron", "le plastron revient dans la case")
	check(Gear.unequip(u, "Torse", u.inventory, 0, u.inventory_capacity), "retirée")
	check_eq(u.inventory[0].get("item", ""), "gear_mail", "dans la case visée")
	check(not u.equipment.has("Torse"), "emplacement vide")


func test_layers_follow_body_frame_in_stack_order() -> void:
	game()
	var u := engineer()
	u.equipment = {"Torse": "gear_iron", "Tête": "gear_helm", "Main gauche": "gear_shield"}
	var base := TyrienArt.anim("walk")[5]
	# Corps « Templier » : la tenue tient lieu d'armure, aucun calque empilé.
	check_eq(TyrienArt.overlays(base, Gear.pieces(u)).size(), 0, "templier : pas de calque d'équipement")
	# L'ordre d'empilement reste valable si un corps les réactive.
	TyrienArt.meta["overlays"] = true
	var layers := TyrienArt.overlays(base, Gear.pieces(u))
	check_eq(layers.size(), 3, "trois calques")
	check(layers[0] == TyrienArt.frames["shield"]["walk"][5], "bouclier d'abord (côté éloigné)")
	check(layers[1] == TyrienArt.frames["iron"]["walk"][5], "puis le plastron")
	check(layers[2] == TyrienArt.frames["helm"]["walk"][5], "casque en dernier")
	check(TyrienArt.overlays(TyrienArt.aim_frame(3, 18), Gear.pieces(u))[1] == TyrienArt.frames["iron"]["aim"][3 * 19 + 18], "visée : même image dans chaque calque")
	TyrienArt.meta["overlays"] = false


func test_inventory_drag_to_slot() -> void:
	game()
	var u := engineer()
	u.unarmored = true
	u.inventory.assign([{"item": "gear_cape", "quantity": 1}])
	var inv := Inventory.new()
	inv._drop({"items": u.inventory, "index": 0, "capacity": 10}, {"equip": "Dos"})
	check_eq(u.equipment.get("Dos", ""), "gear_cape", "cape glissée sur le dos")
	inv._drop({"equip": "Dos"}, {"items": u.inventory, "index": 3, "capacity": 10})
	check_eq(u.inventory[3].get("item", ""), "gear_cape", "rendue au paquetage")
	inv.free()
