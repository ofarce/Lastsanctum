extends "res://tests/econ_case.gd"
## Étape 10, revue des touches (D2) : table des touches identique au prototype (keydown, Index.html:509 ;
## caméra keys.d/q/a/z/w/s et flèches, Index.html:510 ; flèches de hud.js:34).

## ZQSD déplacent l'ingénieur (input_controller._engineer_keys), plus la caméra.
const CAMERA := {"cam_left": [KEY_A, KEY_LEFT], "cam_right": [KEY_RIGHT],
	"cam_up": [KEY_W, KEY_UP], "cam_down": [KEY_DOWN]}


func _ev(k: Key, shift := false, ctrl := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.key_label = k
	e.pressed = true
	e.shift_pressed = shift
	e.ctrl_pressed = ctrl
	return e


func test_camera_keys_match_js() -> void:
	for action: String in CAMERA:
		for k: Key in CAMERA[action]:
			check(InputMap.event_is_action(_ev(k), action), "%s → %s" % [OS.get_keycode_string(k), action])
	# Aucune autre touche de lettre ne déplace la caméra.
	for k in range(KEY_A, KEY_Z + 1):
		var any := false
		for action: String in CAMERA:
			any = any or InputMap.event_is_action(_ev(k as Key), action)
		var expected := [KEY_A, KEY_W].has(k)
		check_eq(any, expected, "%s déplace la caméra : %s" % [OS.get_keycode_string(k), expected])


## Touches du panneau d'actions (27 contextes du prototype) : aucune n'est une touche de caméra.
func test_panel_keys_do_not_collide_with_camera() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/hud/hud_actions.json"))
	var keys := {}
	for c: Dictionary in d["results"]:
		for a: Dictionary in c["hud"]["actions"]:
			keys[a["key"]] = true
	for k: String in ["z", "q", "s", "d", "w", "a"]:
		check(not keys.has(k), "« %s » n'est pas une touche du panneau" % k)


## D2 : Ctrl+A sélectionne toutes les unités visibles ; A seule ne fait que déplacer la caméra.
func test_ctrl_a_selects_all_visible() -> void:
	var sim := game()
	var ic: InputController = sim.get_node("../Input")
	var a := sim.spawn("Archer", -10.0, -120.0, "archer")
	a.hp = 85.0
	var hidden := sim.spawn("Caché", -12.0, -120.0, "archer")
	hidden.hp = 85.0
	hidden.hidden = true
	GameState.selected = []
	ic._key(_ev(KEY_A))
	check_eq(GameState.selected.size(), 0, "A seule : aucune sélection (caméra uniquement)")
	ic._key(_ev(KEY_A, false, true))
	check_eq(GameState.selected.size(), 2, "Ctrl+A : Ingénieur et archer sélectionnés, pas l'unité cachée")
	# P : plus de mode non pixel (retiré, D3) ; ouvre le menu Poser de l'Ingénieur (sim/placeables.gd).
	var px := sim.world.camera.px
	ic._key(_ev(KEY_P))
	check(sim.world.camera.px == px and GameState.selected.size() == 2, "P : caméra inchangée")
	check_eq(GameState.hud_menu, "place", "P : menu Poser")
	ic._key(_ev(KEY_P))
	check_eq(GameState.hud_menu, "", "P : retour aux ordres")
	# Maj+R deux fois : nouvelle partie (le premier ne fait que prévenir) ; Échap : annule le mode et le menu.
	GameState.hud_menu = "build"
	GameState.hud_mode = "build"
	ic._key(_ev(KEY_ESCAPE))
	check(GameState.hud_menu == "" and GameState.hud_mode == "", "Échap : menu et mode annulés")
	var n_before := GameState.units.size()
	ic._key(_ev(KEY_R, true))
	check_eq(GameState.units.size(), n_before, "premier Maj+R : la partie continue (confirmation demandée)")
	ic._key(_ev(KEY_R, true))
	check_eq(GameState.units.size(), 1, "second Maj+R : nouvelle partie (Ingénieur seul)")
	check(GameState.units[0].hidden, "Maj+R : l'Ingénieur attend le portail")


## Événement synthétique sans key_label (MCP, parse_input_event) : la touche agit quand même.
func test_synthetic_key_without_label() -> void:
	var sim := game()
	var ic: InputController = sim.get_node("../Input")
	GameState.selected = [engineer()]
	var e := InputEventKey.new()
	e.keycode = KEY_B
	e.pressed = true
	ic._key(e)
	check_eq(GameState.hud_menu, "build", "B sans key_label ouvre le menu de construction")


## D2 : un raccourci avec Ctrl ne fait pas défiler la caméra, même si Ctrl n'est pas vu comme maintenu
## (événement synthétique) ; A seule la fait défiler.
func test_ctrl_chord_blocks_camera() -> void:
	var sim := game()
	var cam := sim.world.camera
	cam._input(_ev(KEY_A, false, true))
	check(not cam._chords.is_empty(), "Ctrl+A retenu comme raccourci")
	var up := _ev(KEY_A)
	up.pressed = false
	cam._input(up)
	check(cam._chords.is_empty(), "relâcher A libère le raccourci")
