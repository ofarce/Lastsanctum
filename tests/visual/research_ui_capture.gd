extends Node
## Capture (fenêtrée) de l'interface des recherches (planches/recherches-interface-propositions.html, pistes A et D) :
## fiche du panneau central, boutons nommés, file d'attente, puis le grimoire plein écran.

const Ctx := preload("res://tests/hud_context.gd")


## Lancement : godot --path . res://tests/visual/research_ui_capture.tscn -- --out=/chemin/dossier
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
			{"type": "soulwell", "x": 12, "z": -118, "complete": true}],
		"building": 0, "res": {"forge": 240, "vie": 90, "discipline": 260, "savoir": 820}}
	Ctx.apply(sim, c, true)
	GameState.opening_stage = ""
	GameState.orb_active = true
	GameState.research_done["minimap"] = true
	GameState.research_done["fletching"] = true
	var lib: Building = GameState.buildings[0]
	GameState.research_jobs["firing_post"] = {"building": lib, "progress": 4.0}
	GameState.research_jobs["palisades"] = {"building": lib, "progress": 0.0}
	GameState.research_jobs["copper_tips"] = {"building": GameState.buildings[1], "progress": 0.0}
	world.camera.reset()
	world.finish_painting()
	hud.hide_notice()
	await _shot(viewport, hud, out + "recherche_fiche.png", func() -> void: pass)
	await _shot(viewport, hud, out + "recherche_fiche_arbalestrie.png", func() -> void:
		hud.research_card.show_research("modular_crossbow", "3"))
	await _shot(viewport, hud, out + "recherche_fiche_file.png", func() -> void:
		hud.research_card.show_research("palisades", "2"))
	hud.grimoire.toggle()
	await _shot(viewport, hud, out + "grimoire.png", func() -> void:
		hud.grimoire._hover = "verdigris_balm"
		hud.grimoire.queue_redraw())
	# Avance de la simulation : une seule recherche progresse, la file suit.
	sim.paused = false
	sim.update_research(1.0)
	print("file : ", GameState.research_jobs.keys(), " · progrès ", GameState.research_jobs.values().map(func(j: Dictionary) -> float: return j["progress"]))
	print("capture ok")
	get_tree().quit()


func _shot(viewport: SubViewport, hud: Hud, path: String, prep: Callable) -> void:
	hud.set_process(true)
	await get_tree().create_timer(0.4).timeout
	hud.set_process(false)
	prep.call()
	for i in 3:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
