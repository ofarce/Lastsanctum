extends Node2D
## Planche de contrôle des fins de projectiles (world/overlay/shot_ends.gd, planche « Fin des projectiles ») :
## une ligne par projectile et par fin (mur, portée), six images pour un tir vers la droite puis six pour un tir
## vers le bas à gauche. Charge aussi la scène principale pour compiler les scripts branchés.
## godot --path . res://tests/visual/fins_capture.tscn
const OUT := "res://tests/visual/out/fins/"
const CELL := 40.0
const S := 2.0
const KINDS: Array[String] = ["arrow", "orb", "fire", "ichor", "bone", "shard", "or", "spirit", "indra", "medeina", "sigil", "aether"]
const DIRS: Array[Vector2] = [Vector2(1, 0), Vector2(-0.7, 0.7)]

var _half := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("main : ", load("res://main/main.tscn") != null)
	get_window().size = Vector2i(int(CELL * S * 12), int(CELL * S * 12))
	for h in 2:
		_half = h
		queue_redraw()
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "fins_%d.png" % h))
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(CELL * S * 12, CELL * S * 12)), Color("#171a20"))
	for r in 12:
		var kind := KINDS[_half * 6 + r / 2]
		var wall := r % 2 == 0
		var dur: float = ShotEnds.DUR[kind][0 if wall else 1]
		var ball := KINDS.find(kind) >= 7
		for c in 12:
			var dir := DIRS[c / 6]
			var at := Vector2((c + 0.5) * CELL, (r + 0.5) * CELL - 4.0)
			var o := Vector2(c * CELL, r * CELL) * S
			draw_rect(Rect2(o, Vector2(1, CELL * S)), Color("#2c3038"))
			draw_rect(Rect2(o, Vector2(CELL * S, 1)), Color("#2c3038"))
			if wall:
				# Face du mur : trait perpendiculaire au vol, au point de fin.
				var n := Vector2(-dir.y, dir.x).normalized()
				draw_line((at - n * 12.0) * S, (at + n * 12.0) * S, Color("#585e6e"), S)
			ShotEnds.draw(self, S, kind, "wall" if wall else "range", at, at.y + (8.0 if ball else 14.0), dir,
				dur * (c % 6) / 6.0 + 0.001, not ball, 1.0)
