extends "res://tests/econ_case.gd"
## Âges des métaux (sim/ages.gd) : le travail du cuivre puis du fer reste masqué tant que le minerai n'a pas été
## extrait et que le boss qui en garde le savoir (la Martyre, puis Gorge-Cuivre) n'est pas vaincu.


func _closed() -> Simulation:
	var sim := game()
	GameState.ages_open.clear()
	return sim


func test_copper_locked_at_start() -> void:
	_closed()
	check(not HudModel.unlocked("forge"), "Fonderie masquée")
	check(not HudModel.unlocked("creuset"), "Armurerie masquée")
	check_eq(HudModel.lock_reason("forge"), "Âge du cuivre requis", "raison affichée")
	check(not Simulation.recipe_unlocked("copper_ingot"), "lingot de cuivre verrouillé")
	check(not Simulation.recipe_unlocked("sword"), "épée de soldat verrouillée")
	check(not Simulation.recipe_unlocked("pickaxe"), "pioche (fer brut) verrouillée")
	check(Simulation.recipe_unlocked("bow"), "l'arc reste libre")
	for id: String in Ages.RESEARCH_AGE:
		check(not ResearchGrimoire.shown().has(id), "recherche masquée au grimoire : " + id)
	check(not ResearchGrimoire.building_types().has("forge"), "pas de colonne Fonderie au grimoire")


func test_copper_needs_ore_and_martyre() -> void:
	var sim := _closed()
	GameState.collected_items["copper"] = true
	sim.tick(DT)
	check(not Ages.is_open("copper"), "minerai seul : fermé")
	check_eq(Ages.objective()["step"], "1 / 2", "quête à moitié")
	GameState.collected_items.erase("copper")
	GameState.martyre_state = "defeated"
	sim.tick(DT)
	check(not Ages.is_open("copper"), "Martyre seule : fermé")
	GameState.collected_items["copper"] = true
	sim.tick(DT)
	check(Ages.is_open("copper"), "minerai + Martyre : ouvert")
	# La Fonderie demande aussi un temple d'Aether achevé (Catalog.BUILDINGS["forge"]["requires"]).
	built(String(Catalog.BUILDINGS["forge"]["requires"]), 26.0, -112.0)
	check(HudModel.unlocked("forge"), "Fonderie constructible")
	check(Simulation.recipe_unlocked("copper_ingot"), "lingot de cuivre")
	check(not Simulation.recipe_unlocked("iron_ingot"), "lingot de fer encore verrouillé")
	check_eq(Ages.objective()["quest"], "Le secret du fer", "quête suivante")


func test_iron_waits_for_copper_then_gorge() -> void:
	var sim := _closed()
	# Premier tick : Gorge-Cuivre initialise son état (mode « sleep ») ; sa mort est posée ensuite.
	sim.tick(DT)
	GameState.collected_items["iron"] = true
	GameState.gorge["mode"] = "dead"
	sim.tick(DT)
	check(not Ages.is_open("iron"), "le fer attend le cuivre")
	GameState.collected_items["copper"] = true
	GameState.martyre_state = "defeated"
	sim.tick(DT)
	sim.tick(DT)
	check(Ages.is_open("copper") and Ages.is_open("iron"), "cuivre puis fer")
	check(Simulation.recipe_unlocked("iron_ingot") and Simulation.recipe_unlocked("pickaxe"), "travail du fer")
	check(not Ages.is_open("gold"), "l'or n'a pas encore de boss")
	check(Ages.objective().is_empty(), "plus de quête d'âge")


func test_open_age_stays_open() -> void:
	var sim := _closed()
	GameState.collected_items["copper"] = true
	GameState.martyre_state = "defeated"
	sim.tick(DT)
	GameState.martyre_state = ""
	sim.tick(DT)
	check(Ages.is_open("copper"), "un âge ouvert le reste")
