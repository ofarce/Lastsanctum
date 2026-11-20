extends Node
## Capture de l'Ingénieur à l'Arbalestrie (planches/ingenieur-canon-planche.html, piste A) : casque relevé,
## qui se ferme au premier tir, rafale de 2 s, attente 1 s, puis relèvement.
## godot --path . res://tests/visual/cannon_capture.tscn
const OUT := "res://tests/visual/out/cannon/"
const MAIN = preload("res://main/main.tscn")
const SHOTS := [0.0, 0.12, 0.25, 0.6, 2.5, 2.8, 3.2, 4.0]

var _vp: SubViewport
var _eng: Unit
var _t := 0.0
var _next := 0
var _warm := 30


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(400, 300)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	_eng = GameState.units[0]
	_eng.hidden = false
	_eng.unarmored = true
	_eng.equipment["Main droite"] = "cannon"
	_eng.tx = _eng.x
	_eng.tz = _eng.z
	_eng.face = 1
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(_eng.x + 0.5, _eng.z - 0.8), 6)
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()


func _process(delta: float) -> void:
	if _warm > 0:
		_warm -= 1
		return
	_t += delta
	GameState.sim_time = 30.0 + _t
	# Rafale de 0,1 s à 2,1 s : un tir toutes les 0,25 s.
	if _t >= 0.1 and _t <= 2.1 and GameState.sim_time - _eng.sh_t0 >= 0.25:
		_eng.sh_t0 = GameState.sim_time
	if _next < SHOTS.size() and _t >= SHOTS[_next]:
		var name := "%d_%.2fs" % [_next, SHOTS[_next]]
		_next += 1
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		if _next >= SHOTS.size():
			get_tree().quit()
