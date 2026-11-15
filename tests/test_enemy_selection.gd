extends "res://tests/econ_case.gd"
## Écarts voulus après 73b410f :
##  - D13 : portées du lance-flammes (×2) et de l'archer (×4), affichées dans le HUD à côté des dégâts ;
##  - D14 : un clic gauche sur un ennemi le sélectionne et affiche sa fiche dans le HUD.


func test_reach_d13_and_hud_range() -> void:
	var sim := game()
	check_eq(Catalog.FIGHT["flammes"]["reach"], 9.0, "lance-flammes : portée 4,5 × 2")
	check_eq(Catalog.FIGHT["archer"]["reach"], 56.0, "archer : portée 14 × 4")
	check(Catalog.FIGHT["flammes"]["seek"] > Catalog.FIGHT["flammes"]["reach"], "lance-flammes : détection au-delà de la portée")
	check(Catalog.FIGHT["archer"]["seek"] > Catalog.FIGHT["archer"]["reach"], "archer : détection au-delà de la portée")
	var want := {"engineer": "86", "flammes": "9", "archer": "56", "lame": "2,2", "paladin": "2,2", "shooter": "17,2", "healer": "8,6", "guard": "8,6"}
	for role: String in want:
		var u := sim.spawn("U", 0.0, -120.0, role)
		GameState.selected = [u]
		GameState.anchor_selected = false
		GameState.hud_building = null
		check_eq(HudModel.view(sim)["range"], want[role], "portée affichée : " + role)
	GameState.selected = []
	check_eq(HudModel.view(sim)["range"], "—", "sans sélection : —")


func test_left_click_selects_enemy() -> void:
	var sim := game()
	var ic: InputController = sim.get_node("../Input")
	var e := Enemy.make("brute", 10.0, -110.0, 1.0)
	e.hp = 100.0
	GameState.enemies.append(e)
	GameState.selected = [engineer()]
	ic._left_click(ic.project(e.x, 1.0, e.z), false)
	check(GameState.hud_enemy == e, "clic gauche : l'ennemi est sélectionné")
	check(GameState.selected.is_empty(), "les alliés sont désélectionnés")
	var v := HudModel.view(sim)
	check_eq(v["chosen"], Catalog.ENEMY_INFO["brute"]["name"], "nom de l'ennemi")
	check_eq(v["health_text"], "100 / 110", "points de vie")
	check_eq([v["damage"], v["range"], v["armor"], v["speed"]], ["12", "1,5", "0", "1,4"], "statistiques")
	check_eq(v["portrait_key"], "enemy-brute", "portrait")
	check(v["enemy"], "fiche marquée ennemie (barre rouge)")
	check(HudModel.panel_actions(sim).is_empty(), "aucun ordre pour un ennemi")
	# Un clic sur un allié reprend la main.
	var u := engineer()
	ic._left_click(ic.project(u.x, 1.0, u.z), false)
	check(GameState.hud_enemy == null and GameState.selected.size() == 1 and GameState.selected[0] == u, "clic sur l'Ingénieur : l'ennemi est oublié")
	# La mort de l'ennemi efface la sélection.
	ic._left_click(ic.project(e.x, 1.0, e.z), false)
	check(GameState.hud_enemy == e, "ennemi resélectionné")
	e.hp = 0.0
	GameState.enemies.erase(e)
	check_eq(HudModel.view(sim)["chosen"], "Aucune sélection", "ennemi mort : plus de fiche")
	check(GameState.hud_enemy == null, "ennemi mort : sélection effacée")
