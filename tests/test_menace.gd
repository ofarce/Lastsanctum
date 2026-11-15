extends "res://tests/fight_case.gd"
## Menace : compteur cumulatif, distinct des ressources produites par l'Ancre.


func test_soldier_deaths_count_once_and_exclude_beasts() -> void:
	var u := setup("engineer", 1)
	var sim := game_sim()
	foe("creep", 0, -120, 0)
	foe("spitter", 1, -120, 0)
	foe("brute", 2, -120, 0)
	foe("beast", 3, -120, 0)
	foe("creep", 4, -120, 100)
	sim.combat.finish_tick(DT, [u] as Array[Unit])
	check_eq(GameState.menace, 3, "trois soldats morts, hors créature et survivant")
	sim.combat.finish_tick(DT, [u] as Array[Unit])
	check_eq(GameState.menace, 3, "aucun double comptage au tick suivant")


func test_temple_recruitment_only_counts_on_success() -> void:
	var sim := game()
	var b := built("sigil", 15, -130)
	sim.summon_adept(b)
	check_eq(GameState.menace, 0, "fonds insuffisants : aucune menace")
	give(1000)
	sim.summon_adept(b)
	check_eq(GameState.menace, 1, "un nouvel adepte : +1")
	check_eq(GameState.units.back().role, "sigil", "adepte effectivement arrivé")


func test_caserne_counts_on_arrival_not_queueing() -> void:
	var sim := game()
	var b := built("caserne", 15, -130)
	give(1000)
	sim.train_unit(b, "archer")
	check_eq(GameState.menace, 0, "file d'attente : pas encore recruté")
	run(sim, Catalog.CASERNE_TIME + 0.1)
	check_eq(GameState.menace, 4, "sortie de caserne : quatre recrues, +4")
	check_eq(b.queue.size(), 0, "entraînement terminé")


func test_reviving_an_adept_does_not_recruit_again() -> void:
	var u := setup("archer", 1)
	var sim := game_sim()
	var b := built("soulwell", 15, -130)
	give(1000)
	GameState.menace = 7
	u.hp = 0
	sim.on_unit_death(u)
	sim.revive_unit(b, u)
	check(u.alive(), "adepte ressuscité")
	check_eq(GameState.menace, 7, "mort et résurrection ne changent pas la menace")


func test_anchor_does_not_generate_menace() -> void:
	var sim := game()
	GameState.orb_active = true
	GameState.menace = 9
	sim.update_orb(1.0)
	check_eq(GameState.menace, 9, "aucune production passive")
	check_eq(GameState.res["forge"], 1.0, "l'Ancre produit toujours les ressources divines")


func test_new_game_resets_menace() -> void:
	var sim := game()
	GameState.menace = 42
	sim.new_game(SEED)
	check_eq(GameState.menace, 0, "nouvelle partie : 0")


func test_hud_displays_eye_after_population_and_fits() -> void:
	var sim := game()
	GameState.menace = 1234
	var hud: Hud = _main.get_node("Hud")
	hud.refresh()
	check_eq(Hud._res_keys().back(), "menace", "Menace en dernière position")
	check_eq(HudModel.view(sim)["menace"], "1234", "compteur entier dans le modèle")
	var items: Dictionary = hud.get("_res_items")
	check_eq(items["menace"]["value"].text, "1234", "texte affiché")
	check_eq(items["menace"]["icon"].modulate, Color("#df936f"), "œil cuivré")
	check(items["menace"]["icon"].texture != null, "icône rasterisée")
	hud.call("_layout_top", Vector2(1150, 900))
	var panel: Control = hud.get("_res_panel")
	check(panel.position.x + panel.size.x * panel.scale.x <= 1134.1, "bandeau dans la largeur minimale de 1150 px")
	check(items["menace"]["value"].position.x + items["menace"]["value"].size.x < panel.size.x, "valeur dans le panneau")
