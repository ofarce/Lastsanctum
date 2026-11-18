extends "res://tests/econ_case.gd"


func test_bands_sources_road_and_reset() -> void:
	var sim := game()
	var fog = sim.world.fog
	var u := engineer()
	u.x = 100
	u.z = 20
	fog.refresh(sim.state())
	# Au-delà du halo, la jungle reste explorée dès le départ (voile EXPLORED_ALPHA, pas le noir).
	var expected := {0: 0, 12: 0, 14: 13, 16: 26, 18: 51, 20: 77, 24: 128, 28: 204, 30: 204, 32: 204}
	for d: int in expected:
		var alpha: int = fog.image.get_pixelv(Vector2i(u.pos()) + Vector2i(d, 0) - fog.ORIGIN).a8
		check(absi(alpha - int(expected[d])) <= 1, "distance %d, opacité obtenue %d" % [d, alpha])
	var b := Building.create(1, "caserne", 120, 20)
	GameState.buildings.append(b)
	u.hidden = true
	fog.refresh(sim.state())
	check(not fog.visible_at(Vector2(120, 20)), "chantier sans ouvrier")
	b.complete = true
	fog.refresh(sim.state())
	check(fog.visible_at(Vector2(120, 20)), "structure achevée")
	check(fog.visible_at(Vector2(0, 40)) and fog.visible_at(Vector2(0, -85)), "chemin et tunnel")
	var road: Road = sim.state().road
	for z in range(-72, 72):
		var rx := roundi(road.main_x(z)) if road and z > Road.GATE_Z else 4
		check_eq(fog.image.get_pixelv(Vector2i(rx, z) - fog.ORIGIN).a8, 0, "chaussée éclairée en continu (z %d)" % z)
	check_eq(fog.image.get_pixelv(Vector2i(24, 32) - fog.ORIGIN).a8, 128, "pénombre au bord du halo")
	check(not fog.visible_at(Vector2(33, 32)), "noir au-delà du halo")
	sim.new_game(SEED)
	check(not fog.visible_at(Vector2(120, 20)), "nouvelle partie")
	check(fog.visible_at(CaveShape.CORE), "Ancre éteinte")
	check(not fog.visible_at(CaveShape.CHEST), "réserve scellée")
	sim.state().vault_open = true
	sim.state().version += 1
	fog.refresh(sim.state())
	check(fog.visible_at(CaveShape.CHEST), "coffre découvert")


func test_wall_hides_enemy_until_dug() -> void:
	var sim := game()
	var fog = sim.world.fog
	var st := sim.state()
	# Deux excavations séparées par une case de roche dans la montagne.
	var key := Vector2i(-30, -72)
	for dx in [0, 2, 3, 4]:
		st.dug[key + Vector2i(dx, 0)] = true
	st.version += 1
	var origin := Vector2(key * 4 + Vector2i(2, 2))
	var u := engineer()
	u.x = origin.x
	u.z = origin.y
	var e := Enemy.make("brute", u.x + 14, u.z, 0)
	GameState.enemies.append(e)
	var ic: InputController = sim.get_node("../Input")
	fog.refresh(st)
	var pointer := ic.project(e.x, 1, e.z)
	check(fog.visible_at(origin + Vector2(4, 0)), "première paroi visible")
	check(not fog.visible_at(e.pos()) and ic.pick_enemy(pointer) == null, "ennemi occulté")
	var map: Minimap = _main.get_node("Hud").minimap
	var dot := Vector2i(Minimap.map_pt(e.x, e.z))
	map.refresh()
	check_eq(map.frame_image().get_pixelv(dot), Color.BLACK, "aucun point ennemi sur la minicarte")
	var hp := e.hp
	sim.combat.update_units(0.05, [u])
	check_eq(e.hp, hp, "aucun tir automatique derrière la paroi")
	st.dug[key + Vector2i.RIGHT] = true
	st.version += 1
	fog.refresh(st)
	check(fog.visible_at(e.pos()) and ic.pick_enemy(pointer) == e, "ouverture de la ligne de vue")
	map.refresh()
	var marker := map.frame_image().get_pixelv(dot)
	check(marker.r > 0.5 and marker.r > marker.g * 1.8, "ennemi révélé sur la minicarte")


func test_wall_penumbra_and_scout() -> void:
	var sim := game()
	var st := sim.state()
	var origin := Vector2(-120, -280)
	var u := engineer()
	u.x = origin.x
	u.z = origin.y
	# Deux galeries ouvertes à l'intérieur de la même case, séparées par un texel de roche.
	st.found = 1
	for offset in [Vector2.ZERO, Vector2(2, 0), Vector2(1, 1)]:
		var p: Vector2 = origin + offset
		st.open[TerrainState.gal_idx(p.x, p.y)] = 1
	st.version += 1
	var fog = sim.world.fog
	fog.refresh(st)
	check_eq(fog.image.get_pixelv(Vector2i(origin) + Vector2i(2, 0) - fog.ORIGIN).a8, 128, "pénombre derrière le mur")
	check_eq(fog.image.get_pixelv(Vector2i(origin) + Vector2i(1, 1) - fog.ORIGIN).a8, 128, "pénombre en diagonale")
	var scout := sim.spawn("Éclaireur", origin.x + 2, origin.y, "archer")
	fog.refresh(st)
	check(fog.visible_at(scout.pos()), "une autre unité révèle son côté du mur")
	scout.hp = 0
	fog.refresh(st)
	check_eq(fog.image.get_pixelv(Vector2i(scout.pos()) - fog.ORIGIN).a8, 128, "retour en pénombre à la mort de l’éclaireur")


func test_active_portals_and_moving_spark() -> void:
	var sim := game()
	var st := sim.state()
	var fog = sim.world.fog
	var p := Vector2(-41, Simulation.PORTAL.y)
	GameState.deity_active["indra"] = false
	fog.refresh(st)
	check(not fog.visible_at(p), "portail divin éteint")
	GameState.deity_active["indra"] = true
	fog.refresh(st)
	check(fog.visible_at(p), "portail divin actif")
	st.portals.append({"x": 150, "z": 20, "active": true})
	fog.refresh(st)
	check(fog.visible_at(Vector2(150, 20)), "portail maléfique actif")
	st.portals.back()["active"] = false
	fog.refresh(st)
	check(not fog.visible_at(Vector2(150, 20)), "extinction du portail")
	GameState.orb_active = true
	GameState.orb_finished_at = 0
	GameState.sim_time = 2.2
	sim.world.anchor_spark._process(0)
	var lights := sim.world.anchor_spark.lights()
	check(not lights.is_empty(), "étincelle en mouvement")
	if not lights.is_empty():
		var head := Vector2(lights[0]["x"], lights[0]["z"])
		fog.refresh(st)
		check_eq(fog.image.get_pixelv(Vector2i(head.floor()) - fog.ORIGIN).a8, 0, "vision autour de l’étincelle")



func test_explored_ground_outside_current_vision() -> void:
	var sim := game()
	var fog = sim.world.fog
	var u := engineer()
	var point := Vector2(135, 30)
	var pixel: Vector2i = Vector2i(point) - fog.ORIGIN
	u.x = point.x
	u.z = point.y
	fog.refresh(sim.state())
	check_eq(fog.image.get_pixelv(pixel).a8, 0, "terrain en pleine lumière")
	u.x += 28
	fog.refresh(sim.state())
	check_eq(fog.image.get_pixelv(pixel).a8, 204, "le fondu à sept cases est conservé")
	u.x += 12
	fog.refresh(sim.state())
	check_eq(fog.image.get_pixelv(pixel).a8, 204, "terrain mémorisé à 20 %")
	check(not fog.visible_at(point), "aucune vision actuelle sur les ennemis")
	u.x = point.x
	fog.refresh(sim.state())
	check_eq(fog.image.get_pixelv(pixel).a8, 0, "terrain revisité")
	sim.new_game(SEED)
	# Nouvelle partie : la jungle repart « déjà explorée », la montagne repart noire.
	check_eq(fog.image.get_pixelv(pixel).a8, 204, "jungle connue en nouvelle partie")
	check_eq(fog.image.get_pixelv(Vector2i(135, -200) - fog.ORIGIN).a8, 255, "montagne inexplorée en nouvelle partie")
