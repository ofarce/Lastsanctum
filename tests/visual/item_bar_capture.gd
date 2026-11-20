extends Node
## Captures de la barre d'objets de l'Ingénieur incarné et des boutons de zoom au-dessus de la minicarte.
## godot --path . res://tests/visual/item_bar_capture.tscn
const OUT := "res://tests/visual/out/item_bar/"
const MAIN = preload("res://main/main.tscn")
const Ammo := preload("res://data/ammo.gd")

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
	eng.x = -8.0
	eng.z = -150.0
	world.camera.set_view(Vector2(-1.0, -150.0), 3)
	await _shot("1_desincarne_zoom")
	world.camera.set_view(Vector2(-1.0, -150.0), WorldCamera.PX_MAX)
	await _shot("2_zoom_max")
	world.camera.set_view(Vector2(-1.0, -150.0), 3)
	ExileGallery.incarnate(eng)
	await _shot("3_incarne_cases_vides")
	GameState.mining_seal = true
	GameState.research_done["minimap"] = true
	GameState.research_done[Ammo.RESEARCH] = true
	eng.unarmored = true
	eng.equipment["Main droite"] = "cannon"
	GameState.ammo = "indra"
	await _shot("4_incarne_complet")
	var bar: Control = null
	for n in main.find_children("*", "Control", true, false):
		if n.get_script() == preload("res://ui/hud/item_bar.gd"):
			bar = n
	bar._hover = 2
	await _shot("5_survol_balles")
	get_tree().quit()
