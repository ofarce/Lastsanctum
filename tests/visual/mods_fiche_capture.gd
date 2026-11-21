extends Node
## Fiche de l'Exilé en 6 cases de mod : trois mods portés, une épée refusée.
## godot --path . res://tests/visual/mods_fiche_capture.tscn
const OUT := "res://tests/visual/out/mods_fiche/"
const MAIN = preload("res://main/main.tscn")
const Gear := preload("res://data/gear_items.gd")

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
	sim.paused = true
	GameState.sim_time = 30.0
	GameState.opening_stage = ""
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.unarmored = true
	eng.equipment["Main droite"] = "cannon"
	eng.equipment["Torse"] = "combinaison"
	eng.inventory.assign([{"item": "module_veil", "quantity": 1}, {"item": "module_drill", "quantity": 1}, {"item": "module_iris", "quantity": 1}, {"item": "iron_sword", "quantity": 1}, {"item": "module_drill", "quantity": 1}])
	print("voile ", Gear.equip(eng, eng.inventory, 0, "Module 1"), " · foreuse ", Gear.equip(eng, eng.inventory, 1, "Module 5"),
		" · iris ", Gear.equip(eng, eng.inventory, 2, "Module 3"), " · épée en main refusée ", not Gear.equip(eng, eng.inventory, 3, "Main droite"),
		" · épée en mod refusée ", not Gear.equip(eng, eng.inventory, 3, "Module 2"), " · canon toujours là ", eng.equipment.get("Main droite"))
	GameState.mining_seal = true
	Events.inventory_requested.emit()
	await _shot("fiche")
	# Infobulles dessinées (ui/inventory/item_tooltip.gd) : deux mods (paquetage, fiche) et deux objets ordinaires.
	var tips := CanvasLayer.new()
	tips.layer = 128
	_vp.add_child(tips)
	var x := 16.0
	for spec: Array in [[{"item": "module_veil", "quantity": 1}, false], [{"item": "module_iris", "quantity": 1}, true],
			[{"item": "iron_sword", "quantity": 1, "owner": "Soldat Varo"}, false], [{"item": "copper_ingot", "quantity": 12}, false]]:
		var t: Control = preload("res://ui/inventory/item_tooltip.gd").make(spec[0], spec[1])
		t.position = Vector2(x, 16)
		tips.add_child(t)
		x += t.size.x + 8.0
	await _shot("infobulles")
	tips.queue_free()
	# Œil-satellite : porté au repos, puis ping vers un ennemi caché au nord-est, derrière la roche.
	for n in main.find_children("*", "Control", true, false):
		if n.get_script() == preload("res://ui/inventory/engineer_inventory.gd"):
			n.close()
	var world: World = main.get_node("World")
	eng.x = -8.0
	eng.z = -150.0
	world.camera.set_view(Vector2(eng.x, eng.z), 4)
	GameState.sim_time = 40.0
	await _shot("iris_1_porte")
	var foe := Enemy.make("creep", eng.x + 70.0, eng.z - 50.0, 1.0)
	GameState.enemies.append(foe)
	print("ennemi caché ", not world.fog.visible_at(Vector2(foe.x, foe.z)))
	for k in [0.3, 0.42, 0.75, 1.05]:
		GameState.sim_time = 40.0 + k
		await _shot("iris_2_ping_%03d" % int(k * 100))
	GameState.enemies.erase(foe)
	# Linceul : coup absorbé par le voile, puis recharge.
	GameState.sim_time = 50.0
	await _shot("voile_1_porte")
	var hp := eng.hp
	print("coup absorbé ", Loot.veil_absorbs(eng), " · PV inchangés ", eng.hp == hp)
	for k in [0.03, 0.15, 0.6, 8.0]:
		GameState.sim_time = 50.0 + k
		await _shot("voile_2_coup_%04d" % int(k * 100))
	# Foreuse : l'Exilé creuse une case à l'est, les cinq billes passent en mèche.
	GameState.sim_time = 80.0
	eng.veil_ready_at = 0.0
	await _shot("foreuse_1_porte")
	var ci := int(floor((eng.x + 6.0) / 4.0))
	var cj := int(floor(eng.z / 4.0))
	eng.job = {"type": "dig", "cell": {"i": ci, "j": cj}}
	eng.working = true
	for i in 8:
		GameState.sim_time += 0.05
		await RenderingServer.frame_post_draw
	await _shot("foreuse_2_meche")
	GameState.sim_time += 0.13
	await _shot("foreuse_3_meche")
	get_tree().quit()
