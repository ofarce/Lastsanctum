extends "res://tests/test_case.gd"
## Étape 6 (v2) : bulle de dialogue (dialogue.js, 73b410f) et textes fixes du HUD (notice d'ouverture,
## bannières de fin), comparés aux valeurs extraites du prototype (assets/baked/hud/hud_texts.json).

const TEXTS := "res://assets/baked/hud/hud_texts.json"
const DT := 1.0 / 60.0

static var _main: Node


func _game() -> Node:
	_main = shared_main()
	var sim: Simulation = _main.get_node("Simulation")
	sim.paused = true
	sim.new_game(20261114)
	return _main


func _js() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TEXTS))


func _bubble() -> DialogueBubble:
	return (_game().get_node("Hud") as Hud).dialogue


## Sortie du portail. La réplique d'accueil n'est plus affichée en jeu (retirée à la demande) : les tests
## de la bulle l'ouvrent eux-mêmes avec greet_engineer, sauf `greet := false`.
func _emerge(sim: Simulation, greet := true) -> Unit:
	for i in roundi(3.1 / DT):
		sim.tick(DT)
	var u: Unit = GameState.units[0]
	if greet:
		(_main.get_node("Hud") as Hud).dialogue.greet_engineer(u)
	return u


func test_greeting_text_matches_js() -> void:
	var b := _bubble()
	var sim: Simulation = _main.get_node("Simulation")
	check(not b.active(), "aucune bulle au départ")
	var u := _emerge(sim, false)
	check(not b.active(), "plus de bulle d'accueil à la sortie du portail")
	b.greet_engineer(u)
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
	check_eq(b._text.text, b._prefix() + line.left(10), "10 signes après 0,24 s (24 ms par signe)")
	b.tick(line.length() * DialogueBubble.CHAR_TIME)
	check_eq(b._text.text, b._prefix() + line, "ligne complète")
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
	check_eq(b._text.text, "Test : Première ligne.", "Entrée affiche toute la ligne")
	b.advance()
	check_eq(b.index, 1, "Entrée suivante : ligne suivante")
	b.elapsed = 10.0
	b.tick(0.0)
	b.advance()
	check(not b.active(), "Entrée sur la dernière ligne complète : fermeture")


func test_stays_open_when_speaker_hidden() -> void:
	var b := _bubble()
	var sim: Simulation = _main.get_node("Simulation")
	var u := _emerge(sim)
	# Les répliques passent par la bannière du haut de l'écran, plus par une bulle accrochée à l'orateur :
	# elles restent affichées quand il se cache (il parle aussi depuis la capsule).
	u.hidden = true
	b.tick(DT)
	check(b.active(), "reste ouverte quand l'orateur se cache")


func test_equipment_dialogue_after_turrets() -> void:
	var b := _bubble()
	var sim: Simulation = _main.get_node("Simulation")
	var hud: Hud = _main.get_node("Hud")
	var u := _emerge(sim)
	hud.world.camera.set_view(Vector2.ZERO, hud.world.camera.px)
	GameState.orb_active = true
	GameState.spark_pending = true
	GameState.orb_finished_at = GameState.sim_time
	sim.update_orb(0.0)
	check(not b.dialogue.get("any_button", false), "pas de nouvelle réplique avant la reconstruction")
	GameState.sim_time += Simulation.SPARK_ARRIVAL
	var spark := hud.world.anchor_spark
	var bend := Vector2(24.0, -110.0)
	spark._cam_path = PackedVector2Array([u.pos(), bend, Vector2.ZERO])
	sim.update_orb(0.0)
	check_eq(hud.world.camera.cam, Vector2.ZERO, "aucun saut au déclenchement du retour")
	check(not b.active(), "réplique attend l'arrivée de la caméra")
	# Étincelle masquée (AnchorSpark.SHOW) : retour direct en 1 s, sans repasser par son trajet.
	var half := AnchorSpark.RETURN_DURATION * 0.5 if AnchorSpark.SHOW else 0.5
	spark._return_tick(half)
	if AnchorSpark.SHOW:
		check_eq(hud.world.camera.cam, bend, "retour par le coude du trajet aller")
	check(not b.active(), "pas de dialogue à mi-chemin")
	spark._return_tick(half)
	check_eq(hud.world.camera.cam, u.pos(), "caméra recentrée sur l'Ingénieur")
	# Surcharge de l'Ancre (sim/overload.gd) avant le dialogue.
	check(Overload.active() and GameState.overload_unit == u, "surcharge lancée au retour de la caméra")
	check(not b.active(), "pas de dialogue pendant la surcharge")
	var at := Vector2(u.x, u.z)
	u.tx = u.x + 5.0
	while GameState.sim_time < GameState.overload_hit + Overload.BLAST - 0.05:
		sim.tick(0.04)
	check(not u.unarmored and u.hp > 1.0, "armure et PV intacts avant l'éclatement")
	check_eq(Vector2(u.x, u.z), at, "l'Ingénieur reste sur place")
	while GameState.sim_time < GameState.overload_hit + Overload.DIALOGUE - 0.05:
		sim.tick(0.04)
	check(u.unarmored and u.hp == 1.0, "sans armure, à 1 PV")
	check_eq(HudModel.portrait_key(u), "engineer-exil" if TyrienArt.ragged() else "engineer-bare", "portrait sans armure")
	EngineerAim.load_frames()
	check_eq(EngineerAim.frames_bare.size(), EngineerAim.frames.size(), "poses de tir sans armure")
	check(Overload.winded(u), "à genoux")
	check(not b.active(), "dialogue après la chute")
	sim.tick(0.1)
	check_eq(b.line(), "Je suis en vie... Mais mon équipement n'a pas résisté. Et sans lui, impossible de combattre le Credo.", "première réplique")
	b.tick(100.0)
	check(b.active(), "attend un appui sans fermeture automatique")
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	key.echo = true
	hud._input(key)
	check_eq(b.index, 0, "répétition clavier ignorée")
	key.echo = false
	hud._input(key)
	check_eq(b.line(), "Peut-être que la Salamandre peut m'aider. Je devrais pouvoir ériger des temples grâce à mon Enonciation.", "une touche quelconque affiche la seconde réplique")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud._input(click)
	check(not b.active(), "clic ferme la seconde réplique")
	sim.update_orb(0.0)
	check(not b.active(), "séquence déclenchée une seule fois")
	check(Overload.winded(u), "toujours à genoux sans ordre")
	u.tx = u.x + 4.0
	check(not Overload.winded(u), "se relève au premier ordre")
	check(u.unarmored, "reste sans armure")
	sim.new_game(20261114)
	check(not Overload.active() and GameState.overload_unit == null, "nouvelle partie : surcharge remise à zéro")


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
	# Bannière de victoire masquée (tri des répliques du 2026-11-20).
	hud.show_banner(true)
	check(not hud._banner.visible, "pas de bannière de victoire")
	GameState.core_hp = 0.0
	hud.show_banner(false)
	check_eq("%s<br><small>%s</small>" % [hud._banner_title.text, hud._banner_small.text], js["banner_core"], "Ancre perdue")
	# Plus de bannière « L’Ingénieur est tombé » : seule l'Ancre détruite termine la partie (test_defeat).
	_game()
	check_eq(hud._notice_label.text, js["init_notice"], "notice d'ouverture")
	check(not hud._banner.visible, "init() masque la bannière")
