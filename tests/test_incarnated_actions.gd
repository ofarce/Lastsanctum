extends "res://tests/econ_case.gd"
## Incarnation (2026-11-19) : clic droit sur le coffre antique (ouverture / réserve) et Sceau de Minage (mur à
## un bloc en surbrillance, miné au clic droit).


func _incarnate(u: Unit) -> void:
	GameState.incarnated = u
	GameState.selected = [u]


func test_chest_opens_when_close() -> void:
	var sim := game()
	var u := engineer()
	_incarnate(u)
	sim.state().vault_open = true
	u.x = CaveShape.CHEST_SPOT.x + 20.0
	u.z = CaveShape.CHEST_SPOT.y
	sim.open_chest_incarnated(u)
	check(not GameState.base_inventory_unlocked, "trop loin : reste fermé")
	u.x = CaveShape.CHEST_SPOT.x
	sim.open_chest_incarnated(u)
	check(GameState.base_inventory_unlocked, "devant le coffre : ouvert")
	var asked := [false]
	var cb := func() -> void: asked[0] = true
	Events.inventory_requested.connect(cb)
	sim.open_chest_incarnated(u)
	Events.inventory_requested.disconnect(cb)
	check(asked[0], "déjà ouvert : la réserve s'affiche")
	GameState.incarnated = null


func test_mining_seal_highlight_and_dig() -> void:
	var sim := game()
	var u := engineer()
	_incarnate(u)
	var st := sim.state()
	# Un sol praticable à côté d'un mur minable, près du départ.
	var spot := Vector2.INF
	for j in range(-45, -20):
		for i in range(-15, 15):
			var c: Variant = st.dig_cell_at(i, j, Vector2(i * 4.0 + 2.0, j * 4.0 + 6.6))
			var p := Vector2(i * 4.0 + 2.0, j * 4.0 + 4.6)
			if c != null and st.walkable(p.x, p.y) and st.in_dig_reach(i, j, p):
				spot = p
				break
		if spot != Vector2.INF:
			break
	check(spot != Vector2.INF, "un mur minable trouvé")
	u.x = spot.x
	u.z = spot.y
	GameState.mining_seal = false
	check(sim.incarnated_mining_cell(u, spot) == null, "sans sceau : aucune surbrillance")
	GameState.mining_seal = true
	var cell: Variant = sim.incarnated_mining_cell(u, spot + Vector2(0, -3))
	check(cell != null, "avec le sceau : le mur à un bloc est désigné")
	if cell != null:
		sim.incarnated_dig(u, [cell])
		run(sim, 15.0)
		check(st.dug.has(Vector2i(cell["i"], cell["j"])) or st.walkable(cell["i"] * 4.0 + 2.0, cell["j"] * 4.0 + 2.0), "mur miné")
	u.x = 0.0
	u.z = 0.0
	GameState.incarnated = null


func test_first_wave_at_nine_day_two() -> void:
	var at := DayNight.first_wave(0.0)
	check_eq(DayNight.day(at), 2, "jour 2")
	check_eq(DayNight.clock(at), "09:00", "à 9 h")
	check(DayNight.is_day(at), "en plein jour")
	check_eq(DayNight.day(DayNight.first_wave(at + 1.0)), 3, "9 h passée : le lendemain")


func test_library_research_minimap_and_firing_post() -> void:
	var sim := game()
	var lib := built("library", -26.0, -118.0)
	staff(sim, lib)
	var ws := built("workshop", 24.0, -118.0)
	check(not Simulation.recipe_unlocked("firing_post"), "poste de tir verrouillé au départ")
	check(not Simulation.can_craft(ws, "firing_post"), "Atelier : pas de poste de tir")
	GameState.res["savoir"] = 499.0
	check(not Simulation.can_research(lib, "minimap"), "Minicarte : 500 Savoir requis")
	GameState.res["savoir"] = 500.0
	GameState.res["discipline"] = 500.0
	sim.start_research(lib, "minimap")
	check_near(GameState.res["savoir"], 0.0, 1e-6, "500 Savoir payés")
	sim.start_research(lib, "firing_post")
	check_near(GameState.res["discipline"], 0.0, 1e-6, "500 Discipline payés")
	run(sim, Catalog.RESEARCH_TIME * 3.0)
	check(GameState.research_done.has("minimap"), "Minicarte achevée")
	check(GameState.research_done.has("firing_post"), "Poste de tir achevé")
	check(Simulation.can_craft(ws, "firing_post"), "Atelier : poste de tir débloqué")
