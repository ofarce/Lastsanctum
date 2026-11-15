extends "res://tests/econ_case.gd"
## Étape 7 (v2) : Puits des Âmes. Les unités tombées (hors Ingénieur) peuvent revenir pour 200 Vie, avec leur
## niveau et leur expérience.


func test_fallen_and_revive() -> void:
	var sim := game()
	var well := built("soulwell", -30.0, -104.0)
	var a := sim.spawn("Adepte archer", 0.0, -120.0, "archer")
	a.level = 3
	a.xp = 40.0
	a.hp = 0.0
	sim.on_unit_death(a)
	check(GameState.fallen.has(a), "âme en attente")
	sim.on_unit_death(engineer())
	check(not GameState.fallen.has(engineer()), "l'Ingénieur ne rejoint pas le Puits")
	GameState.res["vie"] = 150.0
	sim.revive_unit(well, a)
	check(GameState.fallen.has(a), "150 Vie : résurrection refusée")
	GameState.res["vie"] = 250.0
	sim.revive_unit(well, a)
	check(not GameState.fallen.has(a), "rappelé")
	check_near(GameState.res["vie"], 50.0, 1e-9, "200 Vie payés")
	check(a.alive() and a.hp == a.max_hp, "PV pleins")
	check_eq(a.level, 3, "niveau conservé")
	check_eq(a.xp, 40.0, "expérience conservée")
	check(a.z > well.z, "devant le Puits : %s" % a.pos())
	check(sim.state().walkable(a.x, a.z), "sur un sol praticable")


func test_revive_actions_list() -> void:
	var sim := game()
	var well := built("soulwell", -30.0, -104.0)
	for i in 11:
		var a := sim.spawn("Adepte de Sigil", 0.0, -120.0, "sigil")
		a.hp = 0.0
		sim.on_unit_death(a)
	GameState.hud_building = well
	GameState.selected = []
	var acts := HudModel.panel_actions(sim)
	check_eq(acts.size(), 9, "9 âmes au plus dans le panneau")
	check_eq(acts[0]["id"], "revive-%d" % GameState.fallen[-1].id, "la plus récente d'abord")
