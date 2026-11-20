extends Node
## Capture des Pylônes de Merenor : galerie du premier pylône découverte, meute et alpha, renaissance avec
## minuteur, canalisation par un esprit de chaque dieu, rupture. godot --path . res://tests/visual/pylon_capture.tscn
const OUT := "res://tests/visual/out/pylone/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		sim.tick(1.0 / 60.0)


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
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	var st := sim.state()
	# Pylône le plus proche de la salle.
	var p: Dictionary = st.portals[0]
	for q: Dictionary in st.portals:
		if Vector2(q["x"], q["z"]).length() < Vector2(p["x"], p["z"]).length():
			p = q
	var c := Vector2(p["x"], p["z"])
	print("pylône ", p["id"], " en ", c, " · ", st.portals.size(), " pylônes")
	world.terrain_ops.reveal_gallery(c.x, c.y)
	_run(sim, 0.5)
	print("éveillé ", p["active"], " · meute ", (p.get("slots", []) as Array).size())
	eng.x = c.x + 14.0
	eng.z = c.y + 10.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.selected = []
	GameState.incarnated = null
	sim.paused = true
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.camera.set_view(c + Vector2(0, -2), 3)
	world.fog.refresh(st)
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("1_meute")
	var ic: Node = main.get_node("Input")
	var top: Vector2 = world.camera.project(c.x, 0.0, c.y) - Vector2(0, 80.0 * world.camera.px)
	var hit: Dictionary = ic.call("hit_pylon", top)
	print("clic sur le haut de l'obélisque → pylône ", hit.get("id", -1), " (attendu ", p["id"], ") · roche minable dessous ", ic.call("_mining_cell", ic.call("ground", top)) != null)
	# Une bête tuée : minuteur.
	var s0: Dictionary = p["slots"][0]
	(s0["enemy"] as Enemy).hp = 0.0
	sim.paused = false
	_run(sim, 20.0)
	sim.paused = true
	world.camera.set_view(c + Vector2(0, -9), 3)
	await _shot("2_minuteur")
	world.camera.set_view(c + Vector2(0, -2), 3)
	_run(sim, 41.0)
	await _shot("3_renaissance")
	# Corruption : l'Ingénieur dans la nappe.
	var hp0 := eng.hp
	eng.x = c.x + 6.0
	eng.z = c.y + 2.0
	eng.tx = eng.x
	eng.tz = eng.z
	for e: Enemy in GameState.enemies:
		if e.pylon == p:
			e.hp = 0.0
	_run(sim, 0.2)
	var hp1 := eng.hp
	_run(sim, 3.0)
	print("bord ", Pylons.edge(p, eng.x, eng.z), " sol ", st.ground(eng.x, eng.z), " praticable ", st.walkable(eng.x, eng.z))
	print("corrompu ", Pylons.corrupted(st, eng.x, eng.z), " · PV ", hp1, " → ", eng.hp, " (avant ", hp0, ")")
	eng.x = c.x + 26.0
	eng.tx = eng.x
	# Canalisation : un esprit de chaque dieu.
	var spirits: Array[Unit] = []
	for cult: String in Pylons.CULTS:
		var u := sim.spawn("Esprit", c.x + 9.0, c.y + 9.0, cult)
		sim.set_job(u, {"type": "pray_pylon", "pylon": p})
		spirits.append(u)
	_run(sim, 6.0)
	world.camera.set_view(c + Vector2(0, -2), 3)
	for u in spirits:
		print(u.role, " ", u.pos(), " → ", Vector2(u.tx, u.tz), " cache ", u.hidden, " travaille ", u.working, " job ", u.job != null, " vivant ", u.alive())
	print("prient ", p["praying"], " · canalisé ", p["channeled"], " · couverture ", p["cover"])
	await _shot("4_canalise")
	sim.set_job(spirits[1], {"type": "pray_pylon", "pylon": {}})
	spirits[1].job = null
	spirits[1].x = c.x + 30.0
	spirits[1].tx = spirits[1].x
	_run(sim, 1.2)
	await _shot("5_rupture")
	# Bénédiction : l'Ingénieur prie devant le pylône pendant 8 s.
	GameState.incarnated = eng
	eng.x = c.x
	eng.z = c.y + 4.6
	eng.tx = eng.x
	eng.tz = eng.z
	eng.hp = eng.max_hp
	print("E au contact : ", Pylons.toggle_bless(sim))
	_run(sim, 8.0)
	print("bénédiction ", p["blessing"], " · prie ", p["blessing_now"], " · minuteur ", Pylons.timer(p))
	GameState.selected = []
	GameState.incarnated = null
	world.camera.set_view(c + Vector2(0, -7), 3)
	await _shot("6_benediction")
	print("après rupture · canalisé ", p["channeled"], " · couverture ", p["cover"], " · minuteur ", Pylons.timer(p))
	get_tree().quit()
