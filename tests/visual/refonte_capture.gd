extends Node
## Capture de la refonte 16 bits (planches/refonte-16bits.html) : les neuf ennemis redessinés au repos, en attaque
## et morts, la caserne à côté de l'Ingénieur, puis un vrai combat pour voir la flèche, le pilum et l'orbe.
## godot --path . res://tests/visual/refonte_capture.tscn
const OUT := "res://tests/visual/out/refonte/"
const MAIN = preload("res://main/main.tscn")
const KINDS := ["creep", "spitter", "scout", "soldier", "shield", "archer", "beast", "feline", "croc"]

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	_vp.get_texture().get_image().save_png(path)
	print("REFONTE_CAPTURE ", path)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1200, 800)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.unarmored = true
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	GameState.core_hp = 100.0
	sim.tick(1.0 / 60.0)
	var c := eng.pos()
	world.camera.input_enabled = false
	world.wind_scale = 0
	(main.get_node("Hud") as Hud).hide_notice()
	# 1. Fiche figée : repos, attaque, mort ; la caserne et l'Ingénieur sur la rangée du bas.
	var caserne: Array[Unit] = []
	for i in 3:
		var u := sim.spawn("Adepte", c.x - 3.0 + i * 3.0, c.y + 6.0, ["lame", "archer", "flammes"][i])
		u.hidden = false
		caserne.append(u)
	eng.x = c.x - 6.0
	eng.z = c.y + 6.0
	sim.paused = true
	for row in 3:
		for i in KINDS.size():
			var e := Enemy.make(KINDS[i], c.x - 16.0 + i * 4.0, c.y - 6.0 + row * 4.0, 1.0)
			e.face = 1
			if row == 2:
				e.hp = 0
				e.dead = true
				e.died_at = GameState.sim_time - 3.0
				GameState.enemy_corpses.append(e)
			else:
				if row == 1:
					e.attack_started = GameState.sim_time - 0.12
				GameState.enemies.append(e)
	world.fog.refresh(sim.state())
	world.finish_painting()
	world.camera.set_view(c, 3)
	for k in 4:
		world._sync_enemies()
		await get_tree().process_frame
	await _shot("1_fiche")
	# 2. Combat : archer, soldat et Thuriféraire à leur portée de la caserne ; tirs saisis en vol.
	GameState.enemies.clear()
	GameState.enemy_corpses.clear()
	for u in caserne:
		u.x = c.x + 4.0
		u.z = c.y + (caserne.find(u) - 1) * 2.0
		u.tx = u.x
		u.tz = u.z
	eng.x = c.x + 6.0
	eng.z = c.y
	var foes := [["archer", -6.0, -3.0], ["soldier", 0.0, 0.0], ["spitter", -6.0, 3.0]]
	for f: Array in foes:
		var e := Enemy.make(f[0], c.x + f[1], c.y + f[2], 1.0)
		e.cooldown = 0.0
		GameState.enemies.append(e)
	world.camera.set_view(c + Vector2(0, 0), 4)
	GameState.core_hp = 100.0
	sim.paused = false
	for shot in 4:
		for i in 7:
			sim.tick(1.0 / 60.0)
		world.fog.refresh(sim.state())
		sim.paused = true
		await _shot("2_tirs_%d" % shot)
		sim.paused = false
	for e: Enemy in GameState.enemies:
		print("ENNEMI ", e.kind, " portée ", e.reach, " PV ", e.hp)
	# 3. Projectiles figés à mi-vol : flèche (10), pilum (5), orbe (10) vers une cible à l'est.
	sim.paused = true
	GameState.enemies.clear()
	GameState.effects.clear()
	var target := {"x": c.x + 6.0, "z": c.y}
	var shooters := [["archer", 10.0, -4.0], ["soldier", 5.0, 0.0], ["spitter", 10.0, 4.0]]
	for f: Array in shooters:
		var e := Enemy.make(f[0], target["x"] - f[1], c.y + f[2], 1.0)
		e.face = 1
		e.attack_started = GameState.sim_time - 0.1
		GameState.enemies.append(e)
		var to := {"x": target["x"], "z": c.y + f[2]}
		match f[0]:
			"archer": sim.combat.arrow(e, to, Combat.ENEMY_BOW)
			"soldier": sim.combat.pilum(e, to)
			"spitter": sim.combat.spell(e, to)
	for fx: Dictionary in GameState.effects:
		if fx["age"] >= 0.0:
			fx["age"] = fx["duration"] * 0.5
	for u in caserne:
		u.x = c.x + 30.0
		u.tx = u.x
	eng.x = target["x"] + 2.0
	world.fog.refresh(sim.state())
	world.camera.set_view(Vector2(c.x, c.y), 4)
	for k in 3:
		world._sync_enemies()
		await get_tree().process_frame
	print("EFFETS ", GameState.effects.map(func(fx: Dictionary) -> String: return "%s@%.2f/%.2f" % [fx["type"], fx["age"], fx["duration"]]))
	await _shot("3_projectiles")
	get_tree().quit(0)
