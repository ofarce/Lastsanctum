extends Node
## Menu Construire par familles : Ingénieur incarné, début de partie (Temples seuls) puis base avancée.
## godot --path . res://tests/visual/build_menu_capture.tscn
const OUT := "res://tests/visual/out/build_menu/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _built(type: String) -> void:
	var b := Building.create(GameState.buildings.size(), type, -40.0 - GameState.buildings.size() * 3.0, -100.0)
	b.complete = true
	b.progress = Catalog.BUILDINGS[type]["time"]
	b.finished_at = -10.0
	GameState.buildings.append(b)


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
	var hud: Hud = main.get_node("Hud")
	sim.paused = true
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.x = 4.0
	eng.z = -158.0
	GameState.sim_time = 30.0
	GameState.opening_stage = "awake"
	GameState.orb_active = true
	for k in Catalog.RES_ORDER:
		GameState.res[k] = 500.0
	ExileGallery.incarnate(eng)
	world.camera.set_view(eng.pos(), 3)
	GameState.hud_menu = "build"
	hud.refresh(true)
	print("debut: ", hud._inc_buttons.size(), " onglets+retour, ", hud._build_buttons.size(), " batiments")
	await _shot("1_debut_temples")
	for t in ["sigil", "aether", "medeina", "indra", "forge", "scierie", "soulwell"]:
		_built(t)
	GameState.hud_build_family = "production"
	hud.refresh(true)
	print("production: ", hud._build_buttons.size(), " batiments")
	await _shot("2_production")
	var tab: Control = hud._inc_buttons[2]
	var mv := InputEventMouseMotion.new()
	mv.position = tab.get_global_rect().get_center()
	_vp.push_input(mv)
	await get_tree().process_frame
	hud._update_bubble()
	print("bulle: ", hud._build_bubble.visible)
	await _shot("2b_survol_onglet")
	for i in [0, 1]:
		var bb: Control = hud._build_buttons[i]
		var mb := InputEventMouseMotion.new()
		mb.position = bb.get_global_rect().get_center()
		_vp.push_input(mb)
		await get_tree().process_frame
		hud._update_bubble()
		await _shot("2c_survol_batiment_%d" % i)
	GameState.hud_build_family = "military"
	hud.refresh(true)
	print("militaire: ", hud._build_buttons.size(), " batiments")
	await _shot("3_militaire")
	get_tree().quit()
