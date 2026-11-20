extends Node
## Scène d'essai des trois squelettes de la nuit (sim/skeletons.gd) : un trio de colliers, un bubons, un explosif
## autour de l'Ingénieur, dehors, en plein jour pour bien voir. Affiche les mesures dans la console et capture
## chaque règle. godot --path . res://tests/visual/skeleton_capture.tscn [-- --night]
const OUT := "res://tests/visual/out/skeletons/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport
var _world: World
var _sim: Simulation
var _look := Vector2(0, -20)


func _process(_d: float) -> void:
	if _world:
		_world.camera.set_view(_look, 3)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(seconds: float) -> void:
	for _i in roundi(seconds / 0.04):
		GameState.next_wave = 1e9
		_sim.tick(0.04)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1500, 900)
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
	# Avec « -- --night » : en pleine nuit, comme en jeu.
	GameState.sim_time = ((0.8 if OS.get_cmdline_user_args().has("--night") else 0.35) - DayNight.START) * DayNight.LENGTH
	_world.camera.input_enabled = false
	_world.wind_scale = 0
	_world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	var st := _sim.state()
	# Une clairière praticable sur 12 unités autour, dehors.
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
	_look = c
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.max_hp = 100000.0
	eng.hp = eng.max_hp
	eng.x = c.x
	eng.z = c.y
	eng.tx = c.x
	eng.tz = c.y
	var now := GameState.sim_time
	var stats := Catalog.menace_stats(0)
	var trio := Skeletons.raise(_sim, Skeletons.COLLAR, c + Vector2(9, -3), stats, now)
	var bubo: Enemy = Skeletons.raise(_sim, Skeletons.BUBO, c + Vector2(-3, 1), stats, now)[0]
	var bomb: Enemy = Skeletons.raise(_sim, Skeletons.BOMB, c + Vector2(2, 5), stats, now)[0]
	for e: Enemy in GameState.enemies:
		if Skeletons.KINDS.has(e.kind):
			e.stun = 1e6   # immobiles : on mesure les règles, pas le combat
			e.max_hp = 1000.0
			e.hp = 1000.0
	_sim.tick(0.04)
	await _shot("1_sortie_de_terre")
	_run(2.0)
	await _shot("2_les_trois_types")
	# Collier : un membre est emmené à 30 unités, la chaîne le ramène.
	trio[2].x += 30.0
	_sim.tick(0.04)
	var far := 0.0
	for a in trio:
		for b in trio:
			far = maxf(far, a.pos().distance_to(b.pos()))
	print("collier · écart maximal après un écart forcé de 30 u : %.2f u (limite %.0f)" % [far, Skeletons.TETHER])
	await _shot("3_chaine_tendue")
	# Collier touché : éclats.
	var before := GameState.enemy_shots.size()
	_sim.combat.damage(trio[0], 5.0, eng)
	print("collier · éclats partis : %d" % (GameState.enemy_shots.size() - before))
	_sim.combat.damage(trio[0], 5.0, eng)
	print("collier · second coup dans la foulée : %d éclats en vol" % GameState.enemy_shots.size())
	_run(0.5)
	await _shot("4_eclats")
	_run(1.5)
	# Bubons touché : l'Ingénieur est à 3 u, un collier est amené à 2 u (la chaîne le laisse venir : moins de 16 u des autres).
	# L'Ingénieur ne bouge pas : la caméra le suit et décalerait les effets sur la capture.
	trio[1].x = bubo.x + 1.0
	trio[1].z = bubo.z - 2.0
	_sim.tick(0.04)
	var hp_eng := eng.hp
	var hp_col := trio[1].hp
	_sim.combat.damage(bubo, 5.0, eng)
	print("bubons · Ingénieur à %.1f u : %.1f PV perdus ; collier à %.1f u : %.1f PV perdus" % [
		eng.pos().distance_to(bubo.pos()), hp_eng - eng.hp, trio[1].pos().distance_to(bubo.pos()), hp_col - trio[1].hp])
	_run(0.16)
	await _shot("5_bubon")
	_run(1.5)
	# Explosif abattu : agenouillement, souffle, boules de feu.
	hp_eng = eng.hp
	hp_col = trio[1].hp
	var hp_bub := bubo.hp
	GameState.enemy_shots.clear()
	_sim.combat.damage(bomb, 1e6, eng)
	_sim.tick(0.04)
	print("explosif · souffles armés : %d" % GameState.skeleton_blasts.size())
	_run(0.4)
	await _shot("6_a_genoux")
	var t := 0.0
	while not GameState.skeleton_blasts.is_empty() and t < 3.0:
		_sim.tick(0.04)
		t += 0.04
	print("explosif · souffle %.2f s après la mort · boules de feu : %d" % [t + 0.44, GameState.enemy_shots.filter(func(s: Dictionary) -> bool: return s["kind"] == "fire").size()])
	print("explosif · Ingénieur à %.1f u : %.1f PV perdus ; bubons à %.1f u : %.1f ; collier à %.1f u : %.1f" % [
		eng.pos().distance_to(bomb.pos()), hp_eng - eng.hp, bubo.pos().distance_to(bomb.pos()), hp_bub - bubo.hp,
		trio[1].pos().distance_to(bomb.pos()), hp_col - trio[1].hp])
	_run(0.12)
	await _shot("7_souffle")
	_run(0.4)
	await _shot("8_boules_de_feu")
	get_tree().quit()
