extends Node
## Capture (fenêtrée) des boutons « Laiton, trait d'or et cachet » : Bibliothèque, puis Caserne.

const Ctx := preload("res://tests/hud_context.gd")


## Lancement : godot --path . res://tests/visual/research_capture.tscn -- --out=/chemin/dossier
func _ready() -> void:
	var out := "res://tests/visual/out/"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main: Node = load("res://main/main.tscn").instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	var hud: Hud = main.get_node("Hud")
	sim.paused = true
	world.camera.input_enabled = false
	var c := {"name": "bibliotheque", "t": 122, "units": [{"name": "Ingénieur Exilé", "role": "engineer", "x": -13, "z": -147}],
		"buildings": [{"type": "library", "x": -26, "z": -118, "complete": true}, {"type": "caserne", "x": -26, "z": -100, "complete": true},
			{"type": "medeina", "x": 0, "z": -118, "complete": true}, {"type": "soulwell", "x": 12, "z": -118, "complete": true},
			{"type": "warehouse", "x": 24, "z": -118, "complete": true}],
		"fallen": [{"name": "Adepte archer", "role": "archer", "x": 10, "z": -110}],
		"building": 0, "res": {"forge": 240, "vie": 90, "discipline": 260, "savoir": 820}}
	Ctx.apply(sim, c, true)
	GameState.opening_stage = ""
	GameState.orb_active = true
	GameState.research_done["mining_concept"] = true
	GameState.research_done["minimap"] = true
	GameState.research_jobs["firing_post"] = {"building": GameState.buildings[0], "progress": 4.0}
	world.camera.reset()
	world.finish_painting()
	hud.hide_notice()
	await _shot(viewport, hud, out + "research_hud.png", "research-modular_crossbow")
	var caserne: Building = GameState.buildings[1]
	caserne.queue.assign(["flammes", "flammes", "archer"])
	caserne.train = 2.5
	GameState.hud_building = caserne
	await _shot(viewport, hud, out + "caserne_hud.png", "train-archer")
	var temple: Building = GameState.buildings[2]
	sim.summon_adept(temple)
	sim.summon_adept(temple)
	GameState.hud_building = temple
	await _shot(viewport, hud, out + "temple_hud.png", "summon")
	var fallen: Unit = GameState.fallen[0]
	GameState.hud_building = GameState.buildings[3]
	await _shot(viewport, hud, out + "puits_hud.png", "revive-%d" % fallen.id)
	var wh: Building = GameState.buildings[4]
	wh.warehouse_page = 1
	wh.requested_items.append("arrows")
	GameState.hud_building = wh
	await _shot(viewport, hud, out + "entrepot_hud.png", "request-arrows")
	GameState.hud_building = null
	GameState.selected.assign([GameState.units[0]])
	GameState.hud_menu = "place"
	await _shot(viewport, hud, out + "poser_hud.png", "place-barricade")
	GameState.hud_menu = ""
	GameState.units[0].ability = 9.0
	GameState.hud_mode = "move"
	await _shot(viewport, hud, out + "ingenieur_hud.png", "repair")
	GameState.hud_mode = ""
	GameState.selected.clear()
	GameState.anchor_selected = true
	await _shot(viewport, hud, out + "ancre_hud.png", "offering")
	print("capture ok")
	get_tree().quit()


## Capture, puis bulle forcée au-dessus du bouton `bubble_id` (le survol n'est pas simulable dans un SubViewport).
func _shot(viewport: SubViewport, hud: Hud, path: String, bubble_id: String) -> void:
	hud.set_process(true)
	await get_tree().create_timer(0.4).timeout
	for i in 2:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	for ab: ActionButton in hud._buttons:
		if ab.visible and ab.action.get("id", "") == bubble_id:
			var info: Array = ab.action["bubble"]
			hud._build_bubble.set_text(info[0], info[1], info[2], info[3], info[4])
			hud._show_bubble(Vector2(ab.global_position.x + ab.size.x / 2.0, hud._bar.global_position.y))
	hud.set_process(false)
	for i in 3:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path.replace(".png", "_bulle.png")))
