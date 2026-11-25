extends Node
## Ingénieur dans les huit directions (rangées *_dr / *_ur de planches/assets/engineer-maj.js, miroir pour la gauche),
## puis demi-tour est → ouest image par image (pivot par les poses, UnitView._head_step).
## godot --path . res://tests/visual/diag_capture.tscn [-- nu]   (nu : sans Arbalestrie)
const OUT := "res://tests/visual/out/diag/"
const MAIN = preload("res://main/main.tscn")
const DIRS := [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1)]

var _vp: SubViewport
var _eng: Unit
var _t := 0.0
var _next := 0
var _warm := 30
var _fired := 0


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
	if not OS.get_cmdline_user_args().has("nu"):
		_eng.equipment["Main droite"] = "cannon"
	for r: String in GameState.res:
		GameState.res[r] = 999.0
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
	var sim: Simulation = get_child(0).get_child(0).get_node("Simulation")
	# 0,5 s de marche par direction (3 unités/s), photo à 0,35 s ; puis demi-tour est → ouest à 4,5 s (6 photos) ;
	# puis un tir par direction toutes les 0,6 s à partir de 5 s, photo 0,05 s après le tir.
	var k := floori(_t / 0.5)
	if k < 8:
		var d: Vector2 = (DIRS[k] as Vector2).normalized() * 3.0 * delta
		_eng.x += d.x
		_eng.z += d.y
	elif _t < 4.5:
		_eng.x += 3.0 * delta
	elif _t < 4.52:
		_eng.x -= 0.01
	_eng.tx = _eng.x
	_eng.tz = _eng.z
	var shot := floori((_t - 5.0) / 0.6)
	if _t >= 5.0 and shot < 8 and shot >= _fired:
		_fired = shot + 1
		_eng.attack = 0.0
		sim.combat.gear_attack(_eng, Vector2(_eng.x, _eng.z) + (DIRS[shot] as Vector2) * 8.0)
	(get_child(0).get_child(0).get_node("World") as World).camera.set_view(Vector2(_eng.x + 0.5, _eng.z - 1.0), 6)
	var due := (_next < 8 and _t >= _next * 0.5 + 0.35) or (_next >= 8 and _next < 14 and _t >= 4.5) or (_next >= 14 and _t >= 5.05 + (_next - 14) * 0.6)
	if due:
		var name := "%02d" % _next
		_next += 1
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		if _next >= 22:
			get_tree().quit()
