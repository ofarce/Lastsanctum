extends Node
## Scène d'essai des motifs statiques (planches/motifs-statiques.html, bilan du 2026-11-20) : de nuit, l'Exilé
## incarné entre deux Fanatiques qui meurent (anneau d'ichor annoncé puis en vol) et un Strazhar qui passe en courant
## à trois blocs (éclats fichés puis sillage en V). Le temps avance à la main : seuls les tirs (EnemyShots.tick) et la
## course du Strazhar bougent.
## godot --path . res://tests/visual/motifs_capture.tscn
const OUT := "res://tests/visual/out/motifs/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport
var _world: World
var _sim: Simulation
var _look := Vector2.ZERO
var _straz: Enemy
var _run := Vector2.ZERO


func _process(_d: float) -> void:
	if _world:
		_world.camera.set_view(_look, 3)


func _shot(name: String) -> void:
	_world.fog.refresh(_sim.state())
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


## Avance le temps de s secondes : le Strazhar court (s'il est là), les tirs volent.
func _adv(s: float) -> void:
	for _i in roundi(s / 0.02):
		GameState.sim_time += 0.02
		if _straz != null:
			_straz.x += _run.x * 0.02
			_straz.z += _run.y * 0.02
		EnemyShots.tick(_sim, 0.02)


func _ready() -> void:
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
	GameState.sim_time = (0.8 - DayNight.START) * DayNight.LENGTH
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
		for dx in range(-14, 15, 2):
			for dz in range(-8, 9, 2):
				ok = ok and st.walkable(p.x + dx, p.y + dz)
		if ok:
			c = p
			break
	print("clairière : ", c)
	_look = c + Vector2(0.0, 10.0)
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.max_hp = 100000.0
	eng.hp = eng.max_hp
	eng.x = c.x
	eng.z = c.y
	eng.tx = c.x
	eng.tz = c.y
	GameState.incarnated = eng
	# Deux Fanatiques abattus : l'un regarde l'Exilé depuis la droite (brèche à droite), l'autre depuis la gauche.
	for f: Array in [[5.5, -2.0], [-5.0, 3.0]]:
		var e := Enemy.make("creep", c.x + f[0], c.y + f[1], 1.0)
		e.face = -1 if f[0] > 0.0 else 1
		e.hp = 0.0
		e.dead = true
		e.died_at = GameState.sim_time
		GameState.enemy_corpses.append(e)
		EnemyShots.on_death(e)
	_adv(0.3)
	print("annonces : ", GameState.enemy_shots.map(func(s: Dictionary) -> String: return s["kind"]))
	await _shot("1_anneau_annonce")
	_adv(0.6)
	await _shot("2_anneau_vol")
	_adv(1.2)
	# Le Strazhar passe à trois blocs au nord de l'Exilé, de droite à gauche, à sa vitesse de course.
	_straz = Enemy.make("strazhar", c.x + 14.0, c.y - 3.0, 1.0)
	_straz.face = -1
	_run = Vector2(-_straz.speed, 0.0)
	GameState.enemies.append(_straz)
	_adv(1.6)
	print("sillage : ", GameState.enemy_shots.map(func(s: Dictionary) -> String: return s["kind"]))
	await _shot("3_sillage")
	_adv(0.5)
	await _shot("4_sillage_suite")
	get_tree().quit()
