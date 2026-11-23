extends Node
## Temps de démarrage d'une partie (instanciation de main.tscn, une construction du monde, première image) :
## godot --path . --rendering-method gl_compatibility res://tools/worldgen/boot_time.tscn
func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 760)
	add_child(viewport)
	var t0 := Time.get_ticks_msec()
	var main = preload("res://main/main.tscn").instantiate()
	viewport.add_child(main)
	var t1 := Time.get_ticks_msec()
	await RenderingServer.frame_post_draw
	print("démarrage ms ", t1 - t0, " · première image ms ", Time.get_ticks_msec() - t0)
	get_tree().quit()
