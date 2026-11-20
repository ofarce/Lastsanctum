extends Node
## Scène d'essai du bilan « Visibilité des balles » (planches/visibilite-balles.html, 2026-11-20) : de nuit, l'Exilé
## incarné face à un archer, un soldat, un Thuriféraire et un chien de la Bête. Les ennemis sont figés ; les tirs
## partent par EnemyShots et le temps avance à la main (seuls les tirs bougent). Captures : annonces (ligne carmin,
## cercle et éclats du pilum, braise dans la gueule), balles en vol (halo, braise rouge, rivet cyan), éclats.
## godot --path . res://tests/visual/balles_capture.tscn [-- --day]
const OUT := "res://tests/visual/out/balles/"
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
	GameState.sim_time = ((0.35 if OS.get_cmdline_user_args().has("--day") else 0.8) - DayNight.START) * DayNight.LENGTH
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
	for f: Array in [["archer", 9.0, -3.0], ["soldier", -8.0, -3.0], ["spitter", -8.0, 4.0], ["beast", 7.0, 3.5]]:
		var e := Enemy.make(f[0], c.x + f[1], c.y + f[2], 1.0)
		e.face = -1 if f[1] > 0.0 else 1
		e.stun = 1e6
		GameState.enemies.append(e)
		foes[f[0]] = e
	var now := GameState.sim_time
	# Annonces : l'archer vise, le pilum part, les orbes partent.
	var archer: Enemy = foes["archer"]
	archer.shot_aim = eng.pos()
	archer.windup = EnemyShots.windup(archer, eng, archer.pos().distance_to(eng.pos()))
	archer.strike_at = now + archer.windup
	EnemyShots.fire(_sim, foes["soldier"], eng.pos() + Vector2(1.6, 0.8))
	EnemyShots.fire(_sim, foes["spitter"], eng.pos())
	_adv(0.3)
	# Le chien crache : l'annonce commence (le chien n'est plus étourdi le temps de l'appel).
	var dog: Enemy = foes["beast"]
	dog.stun = 0.0
	dog.spit_at = GameState.sim_time - 1.0
	EnemyShots.spit(_sim, dog, eng, dog.pos().distance_to(eng.pos()))
	dog.stun = 1e6
	print("crachat annoncé : départ dans %.2f s" % (dog.spit_fire_at - GameState.sim_time))
	dog.stun = 0.0
	_adv(0.18)
	print("Exilé à l'écran : ", _world.camera.project(eng.x, 0.0, eng.z))
	await _shot("1_annonces")
	# Balles en vol : la flèche part, le crachat sort de la gueule, l'Exilé riposte (rivet cyan).
	archer.strike_at = INF
	EnemyShots.fire(_sim, archer, archer.shot_aim)
	archer.shot_aim = null
	_adv(0.2)
	_sim.combat.rivet(eng, archer)
	for fx: Dictionary in GameState.effects:
		if fx["type"] == "rivet":
			fx["age"] = fx["duration"] * 0.5
	print("tirs en vol : ", GameState.enemy_shots.map(func(s: Dictionary) -> String: return s["kind"]))
	await _shot("2_balles")
	_adv(0.3)
	print("après l'impact du pilum : ", GameState.enemy_shots.map(func(s: Dictionary) -> String: return s["kind"]))
	await _shot("3_eclats")
	get_tree().quit()
