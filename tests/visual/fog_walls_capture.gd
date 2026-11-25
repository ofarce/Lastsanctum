extends Node
## Voile des murs pleins du Temple pendant et après la peinture progressive (correctif du 2026-11-23).
## godot --path . res://tests/visual/fog_walls_capture.tscn
const OUT := "res://tests/visual/out/fog_walls/"
const MAIN = preload("res://main/main.tscn")
const FOG = preload("res://world/terrain/fog_of_war.gd")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 600)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var main := MAIN.instantiate()
	vp.add_child(main)
	var world: World = main.get_node("World")
	(main.get_node("Hud") as CanvasLayer).visible = false
	var ts: TerrainState = world.terrain_state
	world.fog.refresh(ts)
	world.terrain_ops.painter.finish()
	world.fog.refresh(ts)
	# Murs pleins de la zone sans brouillard restés découverts (doit valoir 0).
	var fog = world.fog
	var bad := 0
	var total := 0
	for ty in range(ceili(float(FOG.clear_row) / FOG.CELL_SIZE) + 1, FOG.SIZE.y / FOG.CELL_SIZE - 1):
		for tx in range(1, FOG.SIZE.x / FOG.CELL_SIZE - 1):
			if fog._full_rock(ts, Vector2i(tx, ty)):
				total += 1
				var i: int = ((ty * FOG.CELL_SIZE + 1) * FOG.SIZE.x + tx * FOG.CELL_SIZE + 1) * 4 + 3
				if fog._explored_pixels[i] != 255:
					bad += 1
	print("FOG_WALLS pleins=%d decouverts=%d" % [total, bad])
	world.camera.set_view(Vector2(0, -60), 1)
	for i in 6:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "fog_walls.png"))
	get_tree().quit()
