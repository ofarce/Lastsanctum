extends Node
## Vérification interactive du HUD (étape 6) dans le jeu réel, fenêtré : les saisies passent par
## Input.parse_input_event, comme celles du joueur (interface d'abord, puis monde).
## Lancement : godot --path . res://tests/visual/hud_interact.tscn
## Captures : tests/visual/out/etape6/jeu_<étape>.png ; journal des vérifications sur la sortie standard.

const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/etape6/"

var main: Node
var sim: Simulation
var world: World
var hud: Hud
var failures := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = MAIN.instantiate()
	add_child(main)
	sim = main.get_node("Simulation")
	world = main.get_node("World")
	hud = main.get_node("Hud")
	sim.new_game(20261114)
	await _wait(1.0)
	_check(hud.dialogue.active() == false, "pas de bulle avant la sortie du portail")
	await _wait_until(func() -> bool: return not GameState.units[0].hidden, 6.0)
	await _wait(0.5)
	_check(hud.dialogue.active(), "bulle d'accueil affichée à la sortie de l'Ingénieur")
	await _shot("accueil")
	# Touche B : menu de construction ; Échap : retour.
	_key(KEY_B)
	await _wait(0.2)
	_check(GameState.hud_menu == "build", "B ouvre le menu de construction")
	_check(hud._build_buttons.size() == 4, "onglet Temples : 4 temples (%d)" % hud._build_buttons.size())
	await _shot("menu_construire")
	var mv := InputEventMouseMotion.new()
	mv.position = hud._build_buttons[1].get_global_rect().get_center()
	Input.parse_input_event(mv)
	await _wait(0.2)
	_check(hud._build_bubble.visible, "survol d'un bâtiment : bulle nom · coût")
	await _shot("menu_construire_survol")
	_key(KEY_ESCAPE)  # ferme d'abord la bulle d'accueil si elle est encore ouverte
	await _wait(0.1)
	if GameState.hud_menu == "build":
		_key(KEY_ESCAPE)
		await _wait(0.1)
	_check(GameState.hud_menu == "", "Échap ferme le menu")
	# Clic sur le bouton « Construire » du panneau, à la souris.
	var b := hud._buttons[0]
	await _click(b.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(GameState.hud_menu == "build", "clic sur Construire")
	await _click(hud._buttons[0].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(GameState.hud_menu == "", "clic sur Retour")
	# Clic gauche sur l'Ancre : panneau de l'Ancre.
	var orb := world.camera.project(CaveShape.CORE.x, 2.6, CaveShape.CORE.y)
	await _click(orb, MOUSE_BUTTON_LEFT)
	_check(GameState.anchor_selected, "clic sur l'Ancre : Ancre sélectionnée")
	await _shot("ancre")
	# R : réactivation depuis le panneau de l'Ancre.
	_key(KEY_R)
	await _wait(0.2)
	_check(GameState.orb_owner != null, "R envoie l'Ingénieur réactiver l'Ancre")
	await _wait(3.0)
	await _shot("reactivation")
	# Clic sur la minicarte : la caméra se déplace.
	var cam0 := world.camera.cam
	var mm := hud.minimap.get_global_rect()
	await _click(mm.position + mm.size * Vector2(0.75, 0.9), MOUSE_BUTTON_LEFT)
	_check(world.camera.cam.distance_to(cam0) > 20.0, "clic sur la minicarte : caméra déplacée (%s)" % world.camera.cam)
	await _shot("minicarte")
	# Un clic sur le bandeau ne doit pas désélectionner ni donner d'ordre au monde.
	world.camera.set_view(WorldCamera.START, world.camera.px)
	GameState.selected = [GameState.units[0]]
	GameState.anchor_selected = false
	var detail := hud._modules[2].get_global_rect().get_center()
	await _click(detail, MOUSE_BUTTON_LEFT)
	_check(GameState.selected.size() == 1, "clic sur le bandeau : sélection conservée")
	# Fréquence d'images sur 3 s, Ancre active et HUD à jour.
	await _wait_until(func() -> bool: return GameState.orb_active, 12.0)
	_check(GameState.orb_active, "Ancre réactivée")
	var frames := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await _wait(3.0)
	var fps := (Engine.get_frames_drawn() - frames) * 1000.0 / (Time.get_ticks_msec() - t0)
	print("im/s : %.1f" % fps)
	await _shot("ancre_active")
	await _economy()
	print("%s : %d échec(s)" % ["OK" if failures == 0 else "ÉCHEC", failures])
	get_tree().quit(1 if failures else 0)


## Étape 7 : construire le Temple de Sigil au clavier et à la souris, invoquer un adepte, le voir prier.
func _economy() -> void:
	var u: Unit = GameState.units[0]
	GameState.res["savoir"] = 75.0
	GameState.selected = [u]
	GameState.anchor_selected = false
	world.camera.set_view(Vector2(-20, -125), world.camera.px)
	_key(KEY_B)
	await _wait(0.1)
	_key(KEY_G)
	await _wait(0.1)
	_check(GameState.hud_mode == "build" and GameState.hud_build_type == "sigil", "B puis G : Temple de Sigil à placer")
	var spot := world.camera.project(-27.0, 0.0, -119.0)
	var before: float = GameState.res["savoir"]
	var t0 := GameState.sim_time
	await _click(spot, MOUSE_BUTTON_LEFT)
	_check(GameState.buildings.size() == 1, "clic sur le sol : chantier posé")
	var b: Building = GameState.buildings[0] if not GameState.buildings.is_empty() else null
	if b == null:
		return
	# L'Ancre active rapporte +1/s pendant les quelques images du clic.
	var paid: float = before + (GameState.sim_time - t0) - GameState.res["savoir"]
	_check(absf(paid - 20.0) < 0.01, "20 Savoir payés (%.3f)" % paid)
	await _wait_until(func() -> bool: return b.progress > 1.6, 10.0)
	_check(sim.kneeling(u), "Ingénieur agenouillé pendant l'Énonciation")
	await _shot("chantier")
	await _wait_until(func() -> bool: return b.complete, 8.0)
	_check(b.complete, "Temple de Sigil achevé")
	# Sélection du temple au clic, puis I : invocation d'un adepte.
	await _click(world.camera.project(b.x, 0.0, b.z - 2.0), MOUSE_BUTTON_LEFT)
	_check(GameState.hud_building == b, "clic sur le temple : temple sélectionné")
	GameState.res["savoir"] = maxf(GameState.res["savoir"], 60.0)
	_key(KEY_I)
	await _wait(0.2)
	var adept: Unit = GameState.units[-1]
	_check(adept.role == "sigil", "I : un adepte de Sigil franchit le portail")
	_check(GameState.deity_active.get("sigil", false), "portail de Sigil actif")
	await _wait_until(func() -> bool: return adept.working, 15.0)
	_check(adept.working, "l'adepte prie au temple")
	await _wait(5.5)
	await _shot("priere")


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "ÉCHEC ") + what)
	if not ok:
		failures += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _wait_until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.key_label = k
		e.physical_keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)


func _click(p: Vector2, button: MouseButton) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await get_tree().process_frame
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = button
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame
	await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "jeu_%s.png" % name))
