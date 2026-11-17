extends Node
## Capture des défenses de l'Atelier posées (sim/placeables.gd) : trois barricades, un poste de tir avec un
## archer, une chausse-trappe sous un ennemi, et l'aperçu de pose. godot --path . res://tests/visual/defenses_capture.tscn
const OUT := "res://tests/visual/out/defenses/"
const MAIN = preload("res://main/main.tscn")
const P := preload("res://sim/placeables.gd")
const Storage := preload("res://sim/item_storage.gd")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1200, 800)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.x = 6.0
	eng.z = -118.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.sim_time = 30.0
	GameState.base_inventory_unlocked = true
	for item: String in {"barricade": 3, "firing_post": 1, "caltrops": 2}:
		for i in {"barricade": 3, "firing_post": 1, "caltrops": 2}[item]:
			Storage.store(GameState.base_inventory, Storage.BASE_CAPACITY, item)
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(14, -126), 3)
	world.wind_scale = 0
	world.finish_painting()
	world.fog.refresh(sim.state())
	for x in [6.0, 10.0, 14.0]:
		P.place(sim, "barricade", Vector2(x, -130.0))
	P.place(sim, "firing_post", Vector2(22.0, -126.0))
	var a := sim.spawn("Archer", 22.0, -127.6, "archer")
	a.tx = a.x
	a.tz = a.z
	P.place(sim, "caltrops", Vector2(26.0, -118.0))
	var e := Enemy.make("brute", 26.0, -118.0, 1.0)
	GameState.enemies.append(e)
	GameState.selected = [eng]
	GameState.hud_menu = "place"
	sim.arm_place("caltrops")
	GameState.build_pointer = Vector2(18.0, -118.0)
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("1_defenses")
	get_tree().quit()
