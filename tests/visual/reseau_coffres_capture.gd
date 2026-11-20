extends Node
## Réseau des coffres et paquetage en bas de l'écran : désincarné, incarné, inventaire page 1 puis page 2.
## godot --path . res://tests/visual/reseau_coffres_capture.tscn
const OUT := "res://tests/visual/out/reseau_coffres/"
const MAIN = preload("res://main/main.tscn")
const Recipes := preload("res://data/recipes.gd")

var _vp: SubViewport


func _shot(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	GameState.sim_time = 30.0
	GameState.opening_stage = ""
	GameState.orb_active = true
	for r: String in Catalog.RES_ORDER:
		GameState.res[r] = 500.0
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.unarmored = true
	eng.x = -8.0
	eng.z = -150.0
	eng.inventory.assign([{"item": "wood", "quantity": 12}, {"item": "copper", "quantity": 5}, {}, {"item": "torch", "quantity": 1}, {"item": "arrows", "quantity": 240}])
	GameState.base_inventory_unlocked = true
	var items: Array = Recipes.ITEMS.keys()
	for i in 157:
		GameState.base_inventory.append({"item": items[i % items.size()], "quantity": 1 + (i * 37) % 400})
	world.camera.set_view(Vector2(-1.0, -150.0), 3)
	await _shot("1_desincarne")
	ExileGallery.incarnate(eng)
	GameState.mining_seal = true
	await _shot("2_incarne")
	ExileGallery.disincarnate()
	Events.inventory_requested.emit()
	await _shot("3_inventaire_page1")
	var inv: Control = null
	for n in main.find_children("*", "Control", true, false):
		if n.get_script() == preload("res://ui/inventory/engineer_inventory.gd"):
			inv = n
	inv._turn(1)
	await _shot("4_inventaire_page2")
	print("pages ", inv.page_count(), " · page ", inv._page)
	get_tree().quit()
