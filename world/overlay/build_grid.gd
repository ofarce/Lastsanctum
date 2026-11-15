class_name BuildGrid
extends Node2D
## Emprises au sol des bâtiments (drawBuildGrid, buildings.js, 73b410f), dessinées avant le décor : fond
## sombre translucide et contour violet pendant le chantier uniquement ; aucune emprise après achèvement,
## épaisseur max(1, Z·0,12) pixels d'écran. Repère : pixels natifs du monde.

var world: World


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var px := float(world.camera.px) if world else 1.0
	var width := maxf(1.0, 8.0 * px / 0.86 * 0.12) / px
	for b in GameState.buildings:
		if b.complete:
			continue
		var h := b.half()
		var pts := PackedVector2Array()
		for c: Vector2 in [Vector2(b.x - h, b.z - h), Vector2(b.x + h, b.z - h), Vector2(b.x + h, b.z + h), Vector2(b.x - h, b.z + h)]:
			pts.append(Proj.nat(c.x, 0.0, c.y))
		draw_colored_polygon(pts, Color("#1a120a2a"))
		var stroke := Color("#c79cff99")
		pts.append(pts[0])
		draw_polyline(pts, stroke, width, true)
