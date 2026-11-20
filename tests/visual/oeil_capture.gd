extends Node
## Capture du boss de la frontière : la salle de l'Œil de la Matrice tout en haut du Temple, la porte de chair,
## le Regard (annonce puis torrent), puis chacune des sept autres attaques, la chute et l'ouverture de la porte.
## Vérifie aussi en console la frontière (roche impossible à creuser, porte infranchissable puis ouverte).
## godot --path . res://tests/visual/oeil_capture.tscn
const OUT := "res://tests/visual/out/oeil/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


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
	var st := world.terrain_state
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.unarmored = true
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	var c := TerrainState.eye_room_center()
	var fz := TerrainState.frontier_z()
	# Frontière : aucune case de la bande ne se creuse hors de la salle ; la porte bloque.
	var diggable := 0
	for i in range(-110, 110, 3):
		if st.frontier_cell(i, floori(fz / 4.0)) and st.dig_cell_at(i, floori(fz / 4.0), Vector2(i * 4.0, fz + 8.0)) != null:
			diggable += 1
	print("frontière : ", st.frontier, " · cases de bande creusables : ", diggable, " · porte ", st.eye_gate.keys(), " fermée ", st.eye_gate_closed)
	print("salle : centre ", c, " galerie ", st.is_gallery(c.x, c.y), " · couloir jusqu'à z ", st.eye_corridor_north)
	print("pylônes dans la salle : ", st.portals.filter(func(p: Dictionary) -> bool: return TerrainState.in_eye_room(p["x"], p["z"], 4.0)).size())
	var hud := main.get_node("Hud") as Hud
	hud.call("_go_oeil")
	print("porte praticable (fermée) : ", st.walkable(0.0, fz - 2.0 + 2.0))
	for i in 30:
		sim.tick(1.0 / 60.0)
	print("état ", GameState.oeil_state, " · boss ", GameState.oeil != null)
	sim.paused = true
	# Caméra libre : sinon elle suit l'Ingénieur incarné.
	GameState.incarnated = null
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.fog.refresh(sim.state())
	world.finish_painting()
	hud.hide_notice()
	world.camera.set_view(c + Vector2(0.0, -2.0), 2)
	await _shot("1_salle")
	world.camera.set_view(Vector2(0.0, fz + 2.0), 3)
	await _shot("2_porte")
	# Duel : l'Ingénieur à l'est, immobile.
	eng.stance = "hold"
	eng.x = c.x + 22.0
	eng.z = c.y + 6.0
	eng.tx = eng.x
	eng.tz = eng.z
	sim.paused = false
	_run(sim, 0.2)
	print("état ", GameState.oeil_state)
	OeilMatrice.run()["next_at"] = GameState.sim_time
	_run(sim, OeilMatrice.LANE["open"] + 0.35)
	sim.paused = true
	world.camera.set_view(c + Vector2(10.0, 0.0), 3)
	await _shot("3_annonce")
	sim.paused = false
	_run(sim, OeilMatrice.LANE["warn"] - 0.35 + 0.5)
	sim.paused = true
	await _shot("4_torrent")
	print("Ingénieur ", eng.hp, " · balles ", GameState.oeil_bullets.size())
	# Chaque attaque de la rotation (planches/oeil-maj.html), capturée en plein motif ; l'Ingénieur ne prend pas de coups.
	var shots := {"larmes": [1, 1.7], "cils": [0, 1.6], "strabisme": [1, 1.9], "pupilles": [1, 2.4], "fixation": [2, 1.6],
		"clignement": [2, 1.15], "milleyeux": [2, 3.2]}
	var n := 7
	for p: String in shots:
		var ph: int = shots[p][0]
		var r := OeilMatrice.run()
		OeilMatrice._extinguish(false)
		GameState.oeil.hp = GameState.oeil.max_hp * [0.9, 0.5, 0.2][ph]
		r["phase"] = ph
		r["intro"] = p
		r["busy_until"] = 0.0
		r["next_at"] = GameState.sim_time
		r["iframe_until"] = INF
		sim.paused = false
		_run(sim, shots[p][1])
		sim.paused = true
		world.camera.set_view(c + Vector2(4.0, 2.0), 2)
		await _shot("%d_%s" % [n, p])
		print(p, " · balles ", GameState.oeil_bullets.size(), " · fx ", GameState.oeil_fx.size(), " · pupilles ",
			GameState.enemies.filter(func(e: Enemy) -> bool: return e.kind == OeilMatrice.PUPIL_KIND).size())
		n += 1
	r_reset(sim)
	sim.paused = false
	GameState.oeil.hp = 0.0
	_run(sim, 0.6)
	sim.paused = true
	await _shot("14_chute")
	print("état ", GameState.oeil_state, " · porte fermée ", st.eye_gate_closed, " · porte praticable ", st.walkable(0.0, fz + 0.5))
	sim.paused = false
	_run(sim, 2.0)
	sim.paused = true
	world.camera.set_view(Vector2(0.0, fz + 2.0), 3)
	await _shot("15_porte_ouverte")
	get_tree().quit()


func r_reset(_sim: Simulation) -> void:
	OeilMatrice._extinguish(false)
	OeilMatrice.run()["iframe_until"] = -INF
	GameState.oeil.hp = GameState.oeil.max_hp


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		sim.tick(1.0 / 60.0)
