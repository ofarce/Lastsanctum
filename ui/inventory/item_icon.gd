extends RefCounted
## Icône de roche partagée entre inventaires et objets au sol.
const Blocks := preload("res://data/mineable_blocks.gd")


static func draw_item(canvas: CanvasItem, item: String, center: Vector2, scale_factor: float) -> void:
	var color: Color = Blocks.ITEMS.get(item, {}).get("color", Color.MAGENTA)
	var points := PackedVector2Array()
	for p: Vector2 in [Vector2(-7, 3), Vector2(-5, -3), Vector2(0, -6), Vector2(6, -3), Vector2(8, 4), Vector2(2, 6), Vector2(-7, 3)]:
		points.append(center + p * scale_factor)
	canvas.draw_colored_polygon(points, color.darkened(0.25))
	canvas.draw_polyline(points, Color("#19262d"), scale_factor)
	canvas.draw_line(center + Vector2(-4, -2) * scale_factor, center + Vector2(0, -4) * scale_factor, color.lightened(0.35), scale_factor)
	canvas.draw_line(center + Vector2(0, -4) * scale_factor, center + Vector2(4, -2) * scale_factor, color, scale_factor)
