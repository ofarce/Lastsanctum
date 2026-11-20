extends Node
## Capture (fenêtrée) de la minicarte plein écran (TAB / M) : base, puis Ingénieur incarné dans la jungle.

const Ctx := preload("res://tests/hud_context.gd")


## Lancement : godot --path . res://tests/visual/minimap_capture.tscn -- --out=/chemin/dossier
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
	var c := {"name": "minicarte", "t": 122, "units": [{"name": "Ingénieur Exilé", "role": "engineer", "x": -13, "z": -147}],
		"buildings": [{"type": "library", "x": -26, "z": -118, "complete": true}], "building": 0, "res": {"savoir": 820}}
	Ctx.apply(sim, c, true)
	GameState.opening_stage = ""
	GameState.orb_active = true
	GameState.research_done["minimap"] = true
	world.camera.reset()
	world.finish_painting()
	hud.hide_notice()
	hud.minimap_overlay.toggle()
	await _shot(viewport, hud, out + "minicarte_base.png")
	var u: Unit = GameState.units[0]
	ExileGallery.incarnate(u)
	u.x = -60.0
	u.z = -40.0
	world.camera.set_view(Vector2(u.x, u.z), world.camera.px)
	world.finish_painting()
	await _shot(viewport, hud, out + "minicarte_incarne.png")
	print("capture ok")
	get_tree().quit()


func _shot(viewport: SubViewport, hud: Hud, path: String) -> void:
	hud.set_process(true)
	hud.refresh(true)
	await get_tree().create_timer(0.4).timeout
	for i in 2:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
