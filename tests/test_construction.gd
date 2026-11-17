extends "res://tests/econ_case.gd"
## Étape 7 (v2) : chantier (placeBuilding, updateBuildings, cancelBuild), comme dans buildings.js (73b410f) :
## paiement, Ingénieur requis sur son point de travail, durée d'Énonciation, annulation remboursée,
## déblocages en chaîne.


func _arm(type: String) -> void:
	GameState.selected = [engineer()]
	GameState.hud_menu = "build"
	GameState.hud_mode = "build"
	GameState.hud_build_type = type


func test_place_pays_and_sends_engineer() -> void:
	var sim := game()
	give(25.0)
	_arm("sigil")
	sim.place_building(Vector2(-27.0, -119.0))
	check_eq(GameState.buildings.size(), 1, "chantier créé")
	var b: Building = GameState.buildings[0]
	check_eq(Vector2(b.x, b.z), Vector2(-28.0, -120.0), "aligné sur la grille (nœud : temple 2 × 2)")
	check_near(GameState.res["savoir"], 5.0, 1e-9, "20 Savoir payés")
	check(engineer().build_job == b and b.owner == engineer(), "Ingénieur affecté")
	check_eq(Vector2(engineer().tx, engineer().tz), b.spot, "envoyé au point de travail")
	check_eq(GameState.hud_mode, "", "mode construction quitté")


func test_invalid_site_and_cost() -> void:
	var sim := game()
	engineer().x = -12.0
	engineer().z = -119.0
	give(25.0)
	_arm("sigil")
	sim.place_building(Vector2(0.0, -120.0))  # allée centrale : désormais constructible
	check_eq(GameState.buildings.size(), 1, "allée centrale acceptée")
	_arm("library")
	sim.place_building(Vector2(-27.0, -119.0))
	check_eq(GameState.buildings.size(), 1, "coût insuffisant : rien de plus n'est construit")
	check_eq(GameState.hud_mode, "", "mode construction quitté faute de ressources")


func test_progress_needs_engineer_on_spot() -> void:
	var sim := game()
	give(25.0)
	_arm("sigil")
	sim.place_building(Vector2(-27.0, -119.0))
	var b: Building = GameState.buildings[0]
	var u := engineer()
	u.x = b.spot.x + 3.0
	u.z = b.spot.y
	u.tx = u.x
	u.tz = u.z
	sim.update_buildings(1.0)
	check_eq(b.progress, 0.0, "pas de progression loin du point de travail")
	u.x = b.spot.x
	u.z = b.spot.y
	check(not sim.kneeling(u), "pas encore agenouillé (progression nulle)")
	sim.update_buildings(1.0)
	check_near(b.progress, 1.0, 1e-9, "1 s d'Énonciation")
	check(sim.kneeling(u), "agenouillé pendant l'Énonciation")
	sim.update_buildings(2.5)
	check(not b.complete, "pas encore achevé à 3,5 s")
	sim.update_buildings(0.6)
	check(b.complete, "achevé après 4 s")
	check_eq(b.finished_at, GameState.sim_time, "instant d'achèvement")
	check(u.build_job == null, "Ingénieur libéré")


func test_fast_construction_toggle_during_work() -> void:
	var sim := game()
	give(25.0)
	_arm("sigil")
	sim.place_building(Vector2(-27.0, -119.0))
	var b: Building = GameState.buildings[0]
	var u := engineer()
	u.x = b.spot.x
	u.z = b.spot.y
	GameState.fast_construction = true
	sim.update_buildings(1.0)
	check_near(b.progress, 2.0, 1e-9, "vitesse doublée")
	GameState.fast_construction = false
	sim.update_buildings(1.0)
	check_near(b.progress, 3.0, 1e-9, "retour à la vitesse normale")
	GameState.fast_construction = true
	sim.update_buildings(0.5)
	check(b.complete, "activation en cours de chantier et achèvement accéléré")
	game()
	check(not GameState.fast_construction, "désactivé en nouvelle partie")


func test_fast_construction_button_and_anchor() -> void:
	var sim := game()
	var hud := _main.get_node("Hud")
	var button: Button = hud.get("_fast_construction")
	var boost: Button = hud.get("_resource_boost")
	check(button.position.y >= boost.position.y + boost.size.y, "bouton sous +1000")
	check(not button.button_pressed and button.text.ends_with("OFF"), "état initial OFF")
	button.button_pressed = true
	check(GameState.fast_construction and button.text.ends_with("ON"), "bouton active le mode rapide")
	var u := engineer()
	u.x = Simulation.ORB_SPOT.x
	u.z = Simulation.ORB_SPOT.y
	u.orb_job = true
	GameState.orb_owner = u
	sim.update_orb(1.0)
	check_near(GameState.orb_progress, 2.0, 1e-9, "réactivation de l’Ancre doublée")
	button.button_pressed = false
	sim.update_orb(1.0)
	check_near(GameState.orb_progress, 3.0, 1e-9, "bouton restaure la vitesse normale")
	button.button_pressed = true
	game()
	check(not button.button_pressed and button.text.ends_with("OFF"), "bouton réinitialisé en nouvelle partie")


func test_walk_and_build_in_real_time() -> void:
	var sim := game()
	give(25.0)
	_arm("sigil")
	sim.place_building(Vector2(-27.0, -119.0))
	var b: Building = GameState.buildings[0]
	run(sim, 7.0)
	check(b.complete, "chantier achevé : trajet puis 4 s d'Énonciation (progression %.2f)" % b.progress)


func test_cancel_refunds() -> void:
	var sim := game()
	give(25.0)
	_arm("sigil")
	sim.place_building(Vector2(-27.0, -119.0))
	var b: Building = GameState.buildings[0]
	b.progress = 2.0
	GameState.selected = [engineer()]
	sim.issue_move(Vector2(-10.0, -125.0))
	check(GameState.buildings.is_empty(), "un ordre de déplacement abandonne le chantier")
	check_near(GameState.res["savoir"], 25.0, 1e-9, "coût remboursé")
	check(engineer().build_job == null, "plus de chantier")


func test_unlock_chain() -> void:
	var sim := game()
	check(not HudModel.unlocked("library"), "Bibliothèque verrouillée")
	var t := built("sigil", -26.0, -118.0)
	check(HudModel.unlocked("library"), "débloquée par le Temple de Sigil achevé")
	t.complete = false
	check(not HudModel.unlocked("library"), "un temple en chantier ne débloque rien")
	check_eq(Simulation.unlock_text("medeina"), " Nouveau : Chambre à coucher, Puits des Âmes.", "texte de déblocage")
	check_eq(Simulation.unlock_text("library"), "", "rien après la Bibliothèque")
	check(sim != null)
