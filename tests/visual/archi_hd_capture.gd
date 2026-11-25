extends Node2D
## Archiprêtre ×3 en jeu : repos, les cinq attaques en pleine tenue, la chute, à l'échelle 3 (un pixel de sprite par
## pixel d'écran). godot --path . res://tests/visual/archi_hd_capture.tscn


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#1c222d"))
	var e := Enemy.make("archipretre", 0.0, 0.0, 1.0)
	e.hidden = false
	e.max_hp = 100.0
	e.hp = 100.0
	var v := ArchipretreView.new()
	var holder := Node2D.new()
	holder.position = Vector2(150, 210)
	holder.scale = Vector2(3, 3)
	add_child(holder)
	holder.add_child(v)
	GameState.archipretre = {"e": e, "idx": 0, "busy_until": -INF}
	v.setup(e, null)
	var rot := Archipretre.rotation()
	var shots := ["idle"]
	shots.append_array(rot)
	shots.append("death")
	var sheet := Image.create(300 * 4, 250 * 2, false, Image.FORMAT_RGBA8)
	var now := 10.0
	for i in shots.size():
		var name: String = shots[i]
		if name == "death":
			e.hp = 0.0
			e.died_at = now - 2.0
		elif name != "idle":
			GameState.archipretre["idx"] = rot.find(name) + 1
			GameState.archipretre["busy_until"] = now + 20.0
			GameState.sim_time = now
			await get_tree().process_frame
			now += 1.6
		GameState.sim_time = now
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, 300, 250), Vector2i((i % 4) * 300, (i / 4) * 250))
		now += 30.0
		GameState.archipretre["busy_until"] = -INF
		GameState.sim_time = now
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("res://tests/visual/out/archi")
	var err := sheet.save_png("res://tests/visual/out/archi/hd.png")
	print("ARCHI_HD_CAPTURE ", err)
	get_tree().quit(0)
