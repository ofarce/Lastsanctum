extends Node
## Capture (fenêtrée) du bouton d'aide et du codex (ui/help), une image par onglet.

const Ctx := preload("res://tests/hud_context.gd")


## Lancement : godot --path . res://tests/visual/help_capture.tscn -- --out=/chemin/dossier
func _ready() -> void:
	var out := "res://tests/visual/out/aide/"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	HelpPanel.persist = false
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
	var c := {"name": "aide", "t": 122, "units": [{"name": "Ingénieur Exilé", "role": "engineer", "x": -13, "z": -147}],
		"buildings": [{"type": "aether", "x": -26, "z": -118, "complete": true}], "res": {"forge": 240}}
	Ctx.apply(sim, c, true)
	GameState.opening_stage = ""
	GameState.orb_active = true
	world.camera.reset()
	world.finish_painting()
	hud.hide_notice()
	await get_tree().create_timer(0.4).timeout
	await _shot(viewport, out + "aide_0_bouton.png")
	hud.help_panel.show_help()
	for i in HelpData.TABS.size():
		hud.help_panel.select(i)
		await _shot(viewport, out + "aide_%d_%s.png" % [i + 1, HelpData.TABS[i]["id"]])
	HelpPanel.world_seen = true
	hud.help_panel.select(HelpData.TABS.size() - 1)
	await _shot(viewport, out + "aide_8_world_ouvert.png")
	hud.help_panel.close()
	print("capture ok, pause rendue : ", sim.paused)
	get_tree().quit()


func _shot(viewport: SubViewport, path: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
