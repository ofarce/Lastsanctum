extends Node
## Captures des chemins de la jungle, brouillard affiché (jungle déjà explorée).
##   godot --path . res://tests/visual/road_capture.tscn  →  tests/visual/out/chemins/*.png

const MAIN := preload("res://main/main.tscn")
const OUT := "res://tests/visual/out/chemins/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main := MAIN.instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	world.camera.input_enabled = false
	sim.new_game(20261114)
	if OS.get_cmdline_user_args().has("--nofog"):
		for c in world.get_children():
			if c is CanvasLayer and (c as CanvasLayer).layer == 3:
				(c as CanvasLayer).visible = false
	var road := world.terrain_state.road
	var shots := [["entree", Vector2(0, -40), 2], ["pont_central", Vector2(0, 20), 2], ["sud", Vector2(road.main_x(55.0), 52), 2]]
	for j in road.junctions:
		shots.append(["croisement_%d" % int(j["side"]), Vector2(j["x"] + float(j["side"]) * 20.0, j["z"] + 6.0), 2])
	shots.append(["vue_large", Vector2(0, 0), 1])
	for p: Dictionary in world.road_props:
		if p["k"] in ["outpost", "cart"]:
			shots.append(["objet_%s_%d" % [p["k"], shots.size()], Vector2(p["x"], p["z"]), 3])
	for s: Array in shots:
		world.camera.set_view(s[1], s[2])
		world.apply_view()
		for i in 4:
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUT + String(s[0]) + ".png")
		print("capture ", s[0])
	get_tree().quit()
