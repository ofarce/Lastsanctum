extends Node
## Capture des attaques partagées du Temple (2026-11-23) : l'Œil de la Matrice joue les motifs de la Martyre en
## phase I, puis une attaque de la phase II et un motif de la phase I ensemble en phase III ; l'Archiprêtre aux
## racines joue les attaques de la phase II de l'Œil. Compte les balles en console et vérifie que les moteurs
## prêtés sont rendus à la chute.
## godot --path . res://tests/visual/boss_mix_capture.tscn
const OUT := "res://tests/visual/out/boss_mix/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		sim.tick(1.0 / 60.0)


func _hold(u: Unit, at: Vector2) -> void:
	u.stance = "hold"
	u.x = at.x
	u.z = at.y
	u.tx = at.x
	u.tz = at.y
	u.force_move = false


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
	GameState.opening_stage = ""
	GameState.in_capsule = false
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.unarmored = true
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	var hud := main.get_node("Hud") as Hud
	GameState.incarnated = null
	world.camera.input_enabled = false
	world.wind_scale = 0

	# ---- Archiprêtre : les cinq attaques de la phase II de l'Œil.
	_run(sim, 0.1)
	var ar := Archipretre.run()
	print("Archiprêtre posé : ", not ar.is_empty(), " · rotation ", Archipretre.rotation())
	if not ar.is_empty():
		var ac := Archipretre.center()
		# Galerie découverte, comme en y marchant : sans cela le voile des murs noircit le champ de vision.
		world.terrain_ops.reveal_gallery(ac.x, ac.y + 12.0)
		if world.terrain_ops.painter:
			world.terrain_ops.painter.terrain.flush()
		_hold(eng, ac + Vector2(10.0, 12.0))
		_run(sim, 0.2)
		print("éveillé ", Archipretre.active(), " · hôte de l'Œil : ", GameState.oeil_host)
		# Le sol de la salle se peint en quelques images réelles, voilé d'ici là (World, fog.veil_cell) : on attend.
		await get_tree().create_timer(4.0).timeout
		world.finish_painting()
		eng.x += 0.5
		world.fog.refresh(sim.state())
		hud.hide_notice()
		# Voile du brouillard masqué pour l'arène : l'Exilé y est téléporté, et le voile la tient pour non vue (disque
		# noir autour de lui, sprite caché). Sans rapport avec les attaques ; à revoir côté brouillard si cela se
		# produit aussi en jeu.
		var veils := world.get_children().filter(func(ch: Node) -> bool:
			return ch is CanvasLayer and ch.get_child_count() > 0 and ch.get_child(0) is ColorRect)
		for l: CanvasLayer in veils:
			l.visible = false
		var waits := {"regard": 1.6, "strabisme": 1.9, "pupilles": 2.4, "larmes": 1.7, "cils": 1.6}
		var n := 1
		for p: String in Archipretre.rotation():
			OeilMatrice.host_clear(false)
			OeilMatrice.run()["iframe_until"] = INF
			# Seul avec le boss : les rencontres de salle et les errants du Temple tueraient l'Exilé immobile.
			GameState.enemies = GameState.enemies.filter(func(e: Enemy) -> bool: return e.kind in [Archipretre.KIND, OeilMatrice.KIND])
			eng.hp = eng.max_hp
			ar["idx"] = n - 1
			ar["busy_until"] = -INF
			ar["next_at"] = GameState.sim_time
			sim.paused = false
			_run(sim, waits[p])
			sim.paused = true
			world.camera.set_view(ac + Vector2(0.0, 8.0), 2)
			await _shot("a%d_%s" % [n, p])
			print("archiprêtre · ", OeilMatrice.run()["pattern"], " · balles ", GameState.oeil_bullets.size(), " · fx ", GameState.oeil_fx.size(),
				" · pupilles ", GameState.enemies.filter(func(e: Enemy) -> bool: return e.kind == OeilMatrice.PUPIL_KIND).size())
			n += 1
		# Les balles touchent : l'Exilé sans invulnérabilité forcée, immobile sous les cils.
		OeilMatrice.run()["iframe_until"] = -INF
		GameState.enemies = GameState.enemies.filter(func(e: Enemy) -> bool: return e.kind in [Archipretre.KIND, OeilMatrice.KIND, OeilMatrice.PUPIL_KIND])
		eng.hp = eng.max_hp
		var hp0 := eng.hp
		sim.paused = false
		_run(sim, 6.0)
		print("Exilé touché par l'Archiprêtre : ", hp0, " → ", eng.hp)
		Archipretre.boss().hp = 0.0
		_run(sim, 2.0)
		print("chute · mode ", ar["mode"], " · hôte de l'Œil : '", GameState.oeil_host, "' · balles ", GameState.oeil_bullets.size(),
			" · fx ", GameState.oeil_fx.size())
		eng.hp = eng.max_hp
		for l: CanvasLayer in veils:
			l.visible = true

	# ---- Œil : motifs de la Martyre en phase I, paires en phase III.
	var c := TerrainState.eye_room_center()
	hud.call("_go_oeil")
	_run(sim, 0.5)
	_hold(eng, c + Vector2(22.0, 6.0))
	_run(sim, 0.2)
	print("Œil : état ", GameState.oeil_state, " · hôte de l'Œil '", GameState.oeil_host, "' · Martyre active ", Martyre.active())
	world.fog.refresh(sim.state())
	world.finish_painting()
	hud.hide_notice()
	var r := OeilMatrice.run()
	var k := 1
	for step: Array in [[0, 0, 1.3], [0, 1, 1.9], [0, 2, 2.1], [0, 3, 2.8], [2, 0, 2.0], [2, 1, 2.3], [2, 2, 2.6], [2, 3, 2.8], [2, 4, 2.0]]:
		OeilMatrice._extinguish(false)
		GameState.oeil.hp = GameState.oeil.max_hp * [0.9, 0.5, 0.2][step[0]]
		r["phase"] = step[0]
		r.erase("intro")
		r["idx"] = step[1]
		r["busy_until"] = 0.0
		r["next_at"] = GameState.sim_time
		r["iframe_until"] = INF
		sim.paused = false
		_run(sim, step[2])
		sim.paused = true
		world.camera.set_view(c + Vector2(4.0, 2.0), 2)
		await _shot("o%d_phase%d_%s" % [k, step[0] + 1, String(r["pattern"]).replace(":", "-")])
		print("œil phase ", step[0] + 1, " · ", r["pattern"], " · balles œil ", GameState.oeil_bullets.size(), " · balles martyre ",
			GameState.martyre_bullets.size(), " · fx martyre ", GameState.martyre_fx.size(), " · hôte martyre '", Martyre.host(), "'")
		k += 1
	# Les motifs prêtés touchent l'Exilé, et l'Œil reprend des PV à la touche.
	OeilMatrice._extinguish(false)
	r["phase"] = 0
	r["idx"] = 3
	r["busy_until"] = 0.0
	r["next_at"] = GameState.sim_time
	r["iframe_until"] = -INF
	GameState.oeil.hp = GameState.oeil.max_hp * 0.9
	var hp1 := eng.hp
	sim.paused = false
	_run(sim, 9.0)
	print("Exilé touché par l'Œil (phase I) : ", hp1, " → ", eng.hp, " · PV de l'Œil ", GameState.oeil.hp / GameState.oeil.max_hp)
	GameState.oeil.hp = 0.0
	_run(sim, 4.0)
	print("chute · état ", GameState.oeil_state, " · hôte martyre '", Martyre.host(), "' · balles martyre ", GameState.martyre_bullets.size(),
		" · fx martyre ", GameState.martyre_fx.size())
	get_tree().quit()
