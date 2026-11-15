extends Node
## Captures du HUD Godot dans les contextes de tools/baker/hud_contexts.json (étape 6), pour la revue
## côte à côte avec les captures du prototype (tools/baker/hud_shot.html).
## Lancement (fenêtré : le rendu headless ne produit pas d'image) :
##   godot --path . res://tests/visual/hud_capture.tscn -- --ctx=nom1,nom2
## Sans --ctx : tous les contextes. Images : tests/visual/out/etape6/hud_<nom>.png (1440×900).

const Ctx := preload("res://tests/hud_context.gd")
const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/etape6/"


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main := MAIN.instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	var hud: Hud = main.get_node("Hud")
	sim.paused = true
	world.camera.input_enabled = false
	var data := Ctx.load_actions()
	var wanted: PackedStringArray = args.get("ctx", "").split(",", false)
	var first := true
	for c: Dictionary in data["contexts"]:
		if not wanted.is_empty() and not wanted.has(c["name"]):
			continue
		Ctx.apply(sim, c, first)
		first = false
		world.camera.reset()
		world.finish_painting()
		hud.hide_notice()
		# Laisse finir la transition de la barre de vie (0,18 s).
		await get_tree().create_timer(0.3).timeout
		for i in 2:
			await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + "hud_%s.png" % c["name"]))
		print("capture hud_%s" % c["name"])
	get_tree().quit()
