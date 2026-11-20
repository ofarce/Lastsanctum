extends Node
## Captures de l'Ancre tyrienne (AnchorView) : éteinte, à mi-réveil, active, survolée.
## godot --path . res://tests/visual/anchor_capture.tscn
const OUT := "res://tests/visual/out/ancre/"
const MAIN = preload("res://main/main.tscn")

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
	sim.paused = true
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.x = 5.5
	eng.z = -151.5
	GameState.sim_time = 30.0
	GameState.opening_stage = "day1"
	world.camera.set_view(CaveShape.CORE + Vector2(0, -1), 4)
	await _shot("1_eteinte")
	GameState.orb_progress = OrbArcs.ORB_TIME * 0.5
	await _shot("2_reveil")
	GameState.orb_progress = 0.0
	GameState.orb_active = true
	eng.x = -1.0
	eng.z = -157.0
	await _shot("3_active")
	GameState.sim_time = 30.4
	eng.x = 2.0
	eng.z = -151.0
	await _shot("4_active_bis")
	get_tree().quit()
