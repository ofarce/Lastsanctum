extends Node
## Capture des recherches achevées en haut à gauche (ResearchShelf) : rangée, puis bulle forcée sur la troisième.
## godot --path . res://tests/visual/research_shelf_capture.tscn -- --out=/chemin/dossier

const Ctx := preload("res://tests/hud_context.gd")


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
		"buildings": [{"type": "library", "x": -26, "z": -118, "complete": true}],
		"building": 0, "res": {"forge": 240, "vie": 90, "discipline": 260, "savoir": 820}}
	Ctx.apply(sim, c, true)
	GameState.opening_stage = ""
	GameState.orb_active = true
	for id in ["minimap", "palisades", "modular_crossbow", "gallery_props", "fletching"]:
		GameState.research_done[id] = true
	world.camera.reset()
	world.finish_painting()
	hud.hide_notice()
	hud.refresh(true)
	await get_tree().create_timer(0.4).timeout
	for i in 2:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "research_shelf.png"))
	hud.research_shelf._set_hover(2)
	for i in 3:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "research_shelf_bulle.png"))
	hud.research_shelf._set_hover(1)
	for i in 3:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "research_shelf_bulle_longue.png"))
	print("capture ok")
	get_tree().quit()
