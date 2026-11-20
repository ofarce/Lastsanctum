extends Node
## Capture (fenêtrée) du panneau d'ordres de l'Atelier (boutons de fabrication « Laiton et objet franc »).

const Ctx := preload("res://tests/hud_context.gd")


## Lancement : godot --path . res://tests/visual/craft_capture.tscn -- --out=/chemin/dossier
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
	var c := {"name": "atelier", "t": 122, "units": [{"name": "Ingénieur Exilé", "role": "engineer", "x": -13, "z": -147}],
		"buildings": [{"type": "aether", "x": -26, "z": -118, "complete": true}, {"type": "workshop", "x": -26, "z": -104, "complete": true}],
		"building": 1, "res": {"forge": 100}}
	Ctx.apply(sim, c, true)
	GameState.opening_stage = ""
	GameState.orb_active = true
	var b: Building = GameState.buildings[1]
	b.recipe = "arrows"
	b.craft = 5.0
	Production.put_into(b.output_box, "arrows", 12)
	Production.put_into(b.output_box, "wood_fiber", 3)
	world.camera.reset()
	world.finish_painting()
	hud.hide_notice()
	await get_tree().create_timer(0.4).timeout
	for i in 2:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "craft_hud.png"))
	# Bulle forcée au-dessus de l'Arc (le survol réel n'est pas simulable dans un SubViewport).
	for ab: ActionButton in hud._buttons:
		if ab.action.get("craft_item", "") == "bow":
			var info: Array = ab.action["bubble"]
			hud._build_bubble.set_text(info[0], info[1], info[2], info[3])
			hud._show_bubble(Vector2(ab.global_position.x + ab.size.x / 2.0, hud._bar.global_position.y))
	hud.set_process(false)
	for i in 3:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "craft_hud_bulle.png"))
	print("capture ok")
	get_tree().quit()
