extends Node2D
## Lanterne de Medeina sur l'Archiprêtre : trois instants du balancement, à ×6.
## godot --path . res://tests/visual/archi_lanterne_capture.tscn


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#1a1420"))
	var views: Array = []
	for i in 3:
		var e := Enemy.make("archipretre", 0.0, 0.0, 1.0)
		e.hidden = false
		e.max_hp = 100.0
		e.hp = 100.0
		var v := ArchipretreView.new()
		v.setup(e, null)
		var holder := Node2D.new()
		holder.position = Vector2(220 + i * 380, 520)
		holder.scale = Vector2(6, 6)
		add_child(holder)
		holder.add_child(v)
		views.append(v)
	for i in 3:
		GameState.sim_time = 10.0 + i * 0.6
		views[i].queue_redraw()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png("res://tests/visual/out/archi/lanterne.png")
	print("ARCHI_CAPTURE ", err)
	get_tree().quit(0)
