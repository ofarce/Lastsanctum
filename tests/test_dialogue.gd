extends "res://tests/test_case.gd"
## Étape 6 (v2) : bulle de dialogue (dialogue.js, 73b410f) et textes fixes du HUD (notice d'ouverture,
## bannières de fin), comparés aux valeurs extraites du prototype (assets/baked/hud/hud_texts.json).

const TEXTS := "res://assets/baked/hud/hud_texts.json"
const DT := 1.0 / 60.0

static var _main: Node


func _game() -> Node:
	if _main == null:
		_main = load("res://main/main.tscn").instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(_main)
	var sim: Simulation = _main.get_node("Simulation")
	sim.paused = true
	sim.new_game(20261114)
	return _main


func _js() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TEXTS))


func _bubble() -> DialogueBubble:
	return (_game().get_node("Hud") as Hud).dialogue


func _emerge(sim: Simulation) -> Unit:
	for i in roundi(3.1 / DT):
		sim.tick(DT)
	return GameState.units[0]


func test_greeting_text_matches_js() -> void:
	var b := _bubble()
	var sim: Simulation = _main.get_node("Simulation")
	check(not b.active(), "aucune bulle au départ")
	var u := _emerge(sim)
	check(b.active(), "bulle d'accueil à la sortie du portail")
	var g: Dictionary = _js()["greeting"]
	check_eq(b.dialogue["lines"], g["lines"], "texte d'accueil")
	check_eq(b.dialogue["name"], g["name"], "nom")
	check_eq(b.dialogue["compact"], g["compact"], "bulle compacte")
	check(b.dialogue["speaker"] == u, "reliée à l'Ingénieur")


func test_typewriter_and_auto_close() -> void:
	var b := _bubble()
	var sim: Simulation = _main.get_node("Simulation")
	_emerge(sim)
	var line: String = b.line()
	b.tick(0.24)
	check_eq(b._text.text, line.left(10), "10 signes après 0,24 s (24 ms par signe)")
	b.tick(line.length() * DialogueBubble.CHAR_TIME)
	check_eq(b._text.text, line, "ligne complète")
	b.tick(3.5 - 0.24 - 0.01)
	check(b.active(), "encore ouverte juste avant longueur × 0,024 + 3,5 s")
	b.tick(0.05)
	check(not b.active(), "fermée automatiquement")


func test_enter_closes_compact_bubble() -> void:
	# advanceCharacterDialogue met elapsed à l'infini : une bulle compacte dépasse alors son délai et se
	# ferme aussitôt (même comportement que le prototype).
	var b := _bubble()
	var sim: Simulation = _main.get_node("Simulation")
	_emerge(sim)
	b.tick(0.1)
	b.advance()
	check(not b.active(), "Entrée pendant l'écriture : fermeture")


func test_enter_completes_line_of_full_dialogue() -> void:
	var b := _bubble()
	var sim: Simulation = _main.get_node("Simulation")
	var u := _emerge(sim)
	b.show_dialogue({"speaker": u, "name": "Test", "compact": false, "lines": ["Première ligne.", "Seconde."]})
	b.tick(0.1)
	b.advance()
	check_eq(b._text.text, "Première ligne.", "Entrée affiche toute la ligne")
	b.advance()
	check_eq(b.index, 1, "Entrée suivante : ligne suivante")
	b.elapsed = 10.0
	b.tick(0.0)
	b.advance()
	check(not b.active(), "Entrée sur la dernière ligne complète : fermeture")


func test_closes_when_speaker_hidden() -> void:
	var b := _bubble()
	var sim: Simulation = _main.get_node("Simulation")
	var u := _emerge(sim)
	u.hidden = true
	b.tick(DT)
	check(not b.active(), "fermée quand l'orateur disparaît")


func test_new_game_closes_dialogue() -> void:
	var b := _bubble()
	var sim: Simulation = _main.get_node("Simulation")
	_emerge(sim)
	check(b.active(), "ouverte")
	sim.new_game(20261114)
	check(not b.active(), "init() ferme le dialogue")


func test_banners_and_notice_match_js() -> void:
	var js := _js()
	var hud: Hud = _game().get_node("Hud")
	hud.show_banner(true)
	check_eq("%s<br><small>%s</small>" % [hud._banner_title.text, hud._banner_small.text], js["banner_won"], "victoire")
	GameState.core_hp = 0.0
	hud.show_banner(false)
	check_eq("%s<br><small>%s</small>" % [hud._banner_title.text, hud._banner_small.text], js["banner_core"], "Ancre perdue")
	GameState.core_hp = 50.0
	GameState.units[0].hp = 0.0
	hud.show_banner(false)
	check_eq("%s<br><small>%s</small>" % [hud._banner_title.text, hud._banner_small.text], js["banner_engineer"], "Ingénieur tombé")
	_game()
	check_eq(hud._notice_label.text, js["init_notice"], "notice d'ouverture")
	check(not hud._banner.visible, "init() masque la bannière")
