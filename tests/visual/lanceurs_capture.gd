extends Node
## Scène d'essai des gestes de tir des lanceurs de boule (tools/lanceurs, choix du 2026-11-23) : de jour, l'Exilé
## incarné entouré d'un Thuriféraire, d'un Fanatique, d'une Aberration, d'un chien de la Bête et d'un squelette
## explosif. La simulation est en pause ; les tirs partent par EnemyShots et le temps avance à la main.
## Captures : charge, juste avant le départ, boules parties, retour de garde.
## godot --path . res://tests/visual/lanceurs_capture.tscn
const OUT := "res://tests/visual/out/lanceurs/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport
var _world: World
var _sim: Simulation
var _look := Vector2.ZERO


func _process(_d: float) -> void:
	if _world:
		_world.camera.set_view(_look, 3)


func _shot(name: String) -> void:
	_world.fog.refresh(_sim.state())
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


## Avance le temps de s secondes pour les seuls tirs (EnemyShots.tick) et les effets.
func _adv(s: float) -> void:
	for _i in roundi(s / 0.02):
		GameState.sim_time += 0.02
		EnemyShots.tick(_sim, 0.02)
		for fx: Dictionary in GameState.effects:
			fx["age"] += 0.02


func _ready() -> void:
	# Après ExileGallery, qui fait suivre l'Exilé incarné par la caméra.
	process_priority = 1000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1500, 1400)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	_sim = main.get_node("Simulation")
	_world = main.get_node("World")
	_sim.new_game(20261114)
	_sim.paused = true
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.wave = 3
	GameState.next_wave = 1e9
	GameState.sim_time = (0.35 - DayNight.START) * DayNight.LENGTH
	_world.camera.input_enabled = false
	_world.wind_scale = 0
	_world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	var st := _sim.state()
	var c := Vector2.ZERO
	for i in 400:
		var p: Variant = Night.spot(_sim)
		if p == null:
			continue
		var ok := true
		for dx in range(-12, 13, 4):
			for dz in range(-8, 9, 4):
				ok = ok and st.walkable(p.x + dx, p.y + dz)
		if ok:
			c = p
			break
	print("clairière : ", c)
	_look = c + Vector2(0.0, 12.0)
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.max_hp = 100000.0
	eng.hp = eng.max_hp
	eng.x = c.x
	eng.z = c.y
	eng.tx = c.x
	eng.tz = c.y
	GameState.incarnated = eng
	var foes := {}
	for f: Array in [["spitter", -9.0, -4.0], ["creep", -8.0, 3.0], ["brute", 9.0, -4.0], ["beast", 9.0, 3.5], ["skeleton_bomb", -2.0, 7.0]]:
		var e := Enemy.make(f[0], c.x + f[1], c.y + f[2], 1.0)
		e.face = -1 if f[1] > 0.0 else 1
		GameState.enemies.append(e)
		foes[f[0]] = e
	var now := GameState.sim_time
	# Thuriféraire : coup annoncé (comme Combat), les orbes partent à la fin de l'annonce.
	var priest: Enemy = foes["spitter"]
	priest.attack_started = now
	priest.windup = EnemyShots.windup(priest, eng, priest.pos().distance_to(eng.pos()))
	# Fanatique, Aberration, squelette : le geste commence dès le prochain tick (release s avant le tir).
	for k: String in ["creep", "brute", "skeleton_bomb"]:
		(foes[k] as Enemy).memo["volley_at"] = now + float(EnemyShots.CAST[k]["release"])
	var dog: Enemy = foes["beast"]
	dog.spit_at = now - 1.0
	EnemyShots.spit(_sim, dog, eng, eng.pos(), dog.pos().distance_to(eng.pos()))
	var fired := false
	var t := 0.0
	for stop: float in [0.02, 0.2, 0.28, 0.4, 0.48, 0.6, 0.72, 0.95]:
		while t < stop - 0.001:
			_adv(0.02)
			t += 0.02
			if not fired and t >= priest.windup:
				fired = true
				EnemyShots.fire(_sim, priest, eng.pos())
		print("%.2f s : " % t, GameState.enemy_shots.map(func(s: Dictionary) -> String: return s["kind"]))
		await _shot("t_%03d" % roundi(t * 100.0))
	get_tree().quit()
