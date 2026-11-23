extends Node
## Captures pour planches/intro-capsule-planche.html : salle de départ (capsule, Ancre), coffre antique posé à
## côté de la capsule. godot --path . res://tests/visual/intro_capsule_capture.tscn
const OUT := "res://tests/visual/out/intro_capsule/"
const MAIN = preload("res://main/main.tscn")
const CHEST_AT := Vector2(7.0, -163.0)

var _vp: SubViewport


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 600)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	var hud: Hud = main.get_node("Hud")
	sim.paused = true
	hud.visible = false
	var eng := Capsule.engineer()
	eng.hidden = true
	eng.unarmored = true
	GameState.in_capsule = true
	GameState.portal_start = -100
	GameState.sim_time = 30.0
	GameState.opening_stage = "day1"
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.finish_painting()
	var chest: Node2D = world.find_children("*", "ChestView", true, false)[0]
	chest.position = Proj.nat(CHEST_AT.x, 0.0, CHEST_AT.y)
	sim.state().vault_open = true
	world.camera.set_view(Vector2(0, -159), 2)
	await _shot("0_large")
	world.camera.set_view(Vector2(2, -160), 3)
	await _shot("1_eteinte")
	sim.state().vault_open = false
	await _shot("1_sans_coffre")
	sim.state().vault_open = true
	GameState.orb_active = true
	GameState.orb_finished_at = GameState.sim_time - 1.0
	await _shot("1b_ancre_allumee")
	sim.state().vault_open = false
	await _shot("1b_sans_coffre")
	sim.state().vault_open = true
	GameState.opening_stage = "link"
	GameState.opening_at = GameState.sim_time - Opening.LINK_LEN * 0.55
	await _shot("2_trait")
	GameState.opening_stage = "awake"
	GameState.capsule_on = true
	GameState.opening_at = GameState.sim_time - 2.0
	await _shot("3_allumee")
	GameState.in_capsule = false
	eng.hidden = false
	eng.x = Capsule.EXIT.x
	eng.z = Capsule.EXIT.y
	eng.tx = eng.x
	eng.tz = eng.z
	await _shot("4_sortie")
	eng.x = CHEST_AT.x - 2.6
	eng.z = CHEST_AT.y + 0.4
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.chest_opened_at = GameState.sim_time - 0.6
	await _shot("5_ouverture")
	GameState.chest_opened_at = GameState.sim_time - 5.0
	await _shot("6_ouvert")
	get_tree().quit()
