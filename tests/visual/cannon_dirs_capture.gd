extends Node
## Ingénieur à l'Arbalestrie de face et de dos (planches/assets/engineer-maj.js, c_idle_d/c_walk_d/c_idle_u/c_walk_u) :
## marche vers le sud, repos, marche vers le nord, repos, tir vers le nord puis vers le sud (munition Indra).
## godot --path . res://tests/visual/cannon_dirs_capture.tscn
const OUT := "res://tests/visual/out/cannon_dirs/"
const MAIN = preload("res://main/main.tscn")
const SHOTS := [0.5, 0.75, 1.6, 2.5, 2.75, 3.6, 4.52, 4.58, 4.7, 4.95, 5.52, 5.58, 5.7, 5.95]

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
	# Munition Indra : la lumière de la bouche prend sa couleur.
	GameState.research_done[preload("res://data/ammo.gd").RESEARCH] = true
	GameState.ammo = "indra"
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
	# Vers le sud de 0 à 1 s, vers le nord de 2 à 3 s (3 unités/s).
	if _t < 1.0:
		_eng.z += 3.0 * delta
	elif _t >= 2.0 and _t < 3.0:
		_eng.z -= 3.0 * delta
	_eng.tx = _eng.x
	_eng.tz = _eng.z
	# Tir vers le nord à 4,5 s puis vers le sud à 5,5 s (poses c_shoot_u / c_shoot_d, balle à la bouche du canon).
	var sim: Simulation = get_child(0).get_child(0).get_node("Simulation")
	if _t >= 4.5 and _t < 5.0 and _eng.sh_t0 < GameState.sim_time - 1.0:
		sim.combat.gear_attack(_eng, Vector2(_eng.x + 0.3, _eng.z - 8.0))
	if _t >= 5.5 and _eng.sh_t0 < GameState.sim_time - 0.9:
		sim.combat.gear_attack(_eng, Vector2(_eng.x + 0.3, _eng.z + 8.0))
	if _next < SHOTS.size() and _t >= SHOTS[_next]:
		var name := "%d_%.2fs" % [_next, SHOTS[_next]]
		_next += 1
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		if _next >= SHOTS.size():
			get_tree().quit()

