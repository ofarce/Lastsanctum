extends "res://tests/econ_case.gd"
## Quêtes de l'Ingénieur (sim/quests.gd) : enchaînement Ancre → La Salamandre → Le Coffre Antique →
## Un mystérieux compagnon (« Bientôt ! »), autels comptés une fois par divinité, étapes du coffre validées
## par la vraie partie (réserve minée, Ingénieur dans la salle, coffre ouvert).


func _temple(deity: String) -> void:
	var b := Building.create(9000 + GameState.buildings.size(), deity, 0.0, 0.0)
	b.complete = true
	GameState.buildings.append(b)


func test_quest_chain() -> void:
	game()
	var q := Quests.new()
	q.update()
	check_eq(q.quest, "anchor", "début : Réactiver l’Ancre")
	check_eq(q.objective()["label"], "Réactiver l’Ancre", "libellé affiché")
	GameState.orb_active = true
	q.update()
	check_eq(q.quest, "", "Ancre restaurée : rien avant la perte d'armure")
	check(q.objective().is_empty(), "aucun objectif affiché")
	engineer().unarmored = true
	q.update()
	check_eq(q.quest, "salamandre", "armure perdue : La Salamandre")
	var o := q.objective()
	check_eq(o["items"].map(func(it: Dictionary) -> String: return it["label"]),
		["Construire un autel à Sigil", "Construire un autel à Indra", "Construire un autel à Medeina", "Construire un autel à Aether"],
		"quatre objectifs indépendants")
	# Chantier inachevé : ne compte pas.
	var site := Building.create(8000, "indra", 0.0, 0.0)
	GameState.buildings.append(site)
	_temple("sigil")
	_temple("sigil")
	q.update()
	check_eq(q.objective()["step"], "1 / 4", "deux temples de Sigil comptent une fois, chantier ignoré")
	check_eq(q.objective()["quote"], Quests.ALTAR_QUOTES["sigil"], "réplique de l'autel de Sigil")
	_temple("medeina")
	_temple("aether")
	q.update()
	check_eq(q.quest, "salamandre", "trois autels sur quatre")
	site.complete = true
	q.update()
	check_eq(q.quest, "chest", "quatre autels : Le Coffre Antique")
	check_eq(q.objective()["label"], "Ouvrir un chemin vers le Coffre Antique", "étape 1")
	GameState.base_inventory_unlocked = true
	q.update()
	check_eq(q.chest_step, 0, "coffre ouvert sans être entré dans la salle : l'étape 1 reste due")
	engineer().hidden = false
	engineer().x = (CaveShape.VAULT_X0 + CaveShape.VAULT_X1) / 2.0
	engineer().z = (CaveShape.VAULT_Z0 + CaveShape.VAULT_Z1) / 2.0
	q.update()
	check_eq(q.quest, "companion", "salle atteinte puis coffre ouvert : quête suivante")
	check(q.objective().get("soon", false), "Un mystérieux compagnon : Bientôt !")
	q.reset()
	check_eq(q.quest, "anchor", "nouvelle partie : retour à l'Ancre")


func test_chest_steps_in_real_game() -> void:
	var sim := game()
	var q := Quests.new()
	q.quest = "chest"
	GameState.mining_seal = true
	q.update()
	check_eq(q.chest_step, 0, "chemin à ouvrir")
	sim.world.dig_cell(14, -37)
	sim.world.dig_cell(15, -37)
	check(sim.order_chest(engineer()), "ordre d'ouvrir le coffre")
	var t := 0.0
	var entered_before_open := false
	while q.quest == "chest" and t < 90.0:
		run(sim, 0.5)
		t += 0.5
		q.update()
		if q.chest_step == 1 and not GameState.base_inventory_unlocked:
			entered_before_open = true
	check(entered_before_open, "l'Ingénieur entre dans la salle avant d'ouvrir le coffre")
	check_eq(q.quest, "companion", "coffre ouvert : Le Coffre Antique terminée")
