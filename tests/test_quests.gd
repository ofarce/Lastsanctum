extends "res://tests/econ_case.gd"
## Quêtes de l'Ingénieur (sim/quests.gd) : Ancre (partie sans ouverture) → Sortir de la capsule → Le Coffre Antique →
## Le plan « Analyse » → La Salamandre → Un mystérieux compagnon (« Bientôt ! »), autels comptés une fois par divinité.


func _temple(deity: String) -> void:
	var b := Building.create(9000 + GameState.buildings.size(), deity, 0.0, 0.0)
	b.complete = true
	GameState.buildings.append(b)


func test_quest_chain() -> void:
	game()
	var q := Quests.new()
	q.update()
	check_eq(q.quest, "anchor", "partie sans ouverture : Réactiver l’Ancre")
	check_eq(q.objective()["label"], "Réactiver l’Ancre", "libellé affiché")
	GameState.orb_active = true
	GameState.in_capsule = true
	q.update()
	check_eq(q.quest, "capsule", "Ancre allumée : sortir de la capsule")
	check_eq(q.objective()["quest"], "Sortir de la capsule", "libellé affiché")
	GameState.in_capsule = false
	q.update()
	check_eq(q.quest, "chest", "dehors : Le Coffre Antique")
	check_eq(q.objective()["label"], "Ouvrir le Coffre Antique", "une seule étape")
	GameState.base_inventory_unlocked = true
	q.update()
	check_eq(q.quest, "analyse", "coffre ouvert : Le plan « Analyse »")
	check_eq(q.objective()["step"], "0 / 2", "rien de fait")
	var etabli := Building.create(9500, "etabli", 0.0, 0.0)
	etabli.complete = true
	GameState.buildings.append(etabli)
	q.update()
	check_eq(q.objective()["step"], "1 / 2", "Établi d'exo construit")
	engineer().unarmored = true
	check_eq(Production.put_into(etabli.output_box, "module_analyse", 1), 0, "mod au coffre rouge")
	q.update()
	check_eq(q.quest, "salamandre", "mod fabriqué, armure perdue : La Salamandre")
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
	check_eq(q.quest, "companion", "quatre autels : quête suivante")
	q.reset()
	check_eq(q.quest, "anchor", "nouvelle partie : retour au début")


func test_opening_starts_at_capsule() -> void:
	var sim := game()
	GameState.opening_stage = "boot"
	GameState.in_capsule = true
	var q := Quests.new()
	q.update()
	check_eq(q.quest, "capsule", "avec la séquence d'ouverture, on saute « Réactiver l’Ancre »")
	q.update()
	check_eq(q.quest, "capsule", "on attend l'Ancre et la sortie")
	GameState.opening_stage = ""
	GameState.in_capsule = false
	sim.new_game(SEED)


func test_chest_quest_in_real_game() -> void:
	var sim := game()
	GameState.orb_active = true
	var q := Quests.new()
	q.update()
	check_eq(q.quest, "chest", "Ingénieur dehors, Ancre allumée")
	check(sim.order_chest(engineer()), "ordre d'ouvrir le coffre")
	var t := 0.0
	while q.quest == "chest" and t < 60.0:
		run(sim, 0.5)
		t += 0.5
		q.update()
	check_eq(q.quest, "analyse", "coffre ouvert : Le Coffre Antique terminée")
