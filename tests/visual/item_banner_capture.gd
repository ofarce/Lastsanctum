extends Node
## Captures des bannières « Reçu : … » à la première entrée dans la capsule : Arbalestrie, puis Combinaison
## qui remplace la première après une action, puis fermeture.
## godot --path . res://tests/visual/item_banner_capture.tscn
const OUT := "res://tests/visual/out/item_banner/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1200, 750)
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
	GameState.sim_time = 30.0
	GameState.opening_stage = "awake"
	GameState.orb_active = true
	GameState.capsule_on = true
	GameState.opening_at = GameState.sim_time - 2.0
	eng.x = 0.0
	eng.z = -163.0
	world.camera.set_view(Vector2(0, -159), 3)
	Capsule.toggle(sim)
	await _shot("1_arbalestrie")
	hud.item_banner._armed_at = 0.0
	hud.item_banner.advance()
	await _shot("2_combinaison")
	hud.item_banner._armed_at = 0.0
	hud.item_banner.advance()
	await _shot("3_fermee")
	print("ACTIVE_AFTER=", hud.item_banner.active())
	get_tree().quit()
