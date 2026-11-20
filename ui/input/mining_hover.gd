extends Node2D
## Surimpression à la résolution écran, au-dessus de l'éclairage et sous le HUD.
var world: World
var cell: Variant = null
var selected_cells: Array[Dictionary] = []


func _draw() -> void:
	if world == null:
		return
	for selected: Dictionary in selected_cells:
		_draw_cell(selected, Color("#f3c96b"), Color("#f3c96b22"))
	if cell != null:
		_draw_cell(cell, Color("#75eef5"), Color("#46ddec2e"), true)


func _draw_cell(target: Dictionary, line_color: Color, fill_color: Color, show_info := false) -> void:
	var px := float(world.camera.px)
	var origin := world.camera.project(target["i"] * 4, 0, target["j"] * 4).round()
	var rect := Rect2(origin, Vector2.ONE * 32 * px)
	draw_rect(rect, fill_color)
	draw_rect(rect.grow(px), Color("#081b22"), false, 3 * px)
	draw_rect(rect, line_color, false, px)
	for point: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1 if point.x == rect.position.x else -1
		var sy := 1 if point.y == rect.position.y else -1
		draw_line(point, point + Vector2(sx * 6 * px, 0), line_color.lightened(0.25), 2 * px)
		draw_line(point, point + Vector2(0, sy * 6 * px), line_color.lightened(0.25), 2 * px)
	if not show_info:
		return
	var block := world.terrain_state.block_definition(target["i"], target["j"])
	var font := ThemeDB.fallback_font
	var title := "Miner : " + str(block.get("material_name", ""))
	var detail := "Clic droit · Case 4 × 4"
	var seal: String = world.terrain_state.seal_needed(target["i"], target["j"])
	if seal != "":
		detail = "Recherche « %s » requise" % Catalog.RESEARCH[seal]["name"]
	if world.terrain_state.permanent_ores.has(Vector2i(cell["i"], cell["j"])):
		detail = "Gisement inépuisable"
	var wood_key := Vector2i(cell["i"], cell["j"])
	if world.terrain_state.grove_cells.has(wood_key):
		detail = "Bois : %d / %d · inépuisable pour Medeina" % [world.terrain_state.wood_left[world.terrain_state.grove_cells[wood_key]], preload("res://data/mineable_blocks.gd").WOOD_YIELD]
	var width := maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) + 26
	var screen := get_viewport_rect().size
	var pos := Vector2(rect.end.x + 14, rect.position.y)
	if pos.x + width > screen.x - 12:
		pos.x = rect.position.x - width - 14
	pos.x = clampf(pos.x, 12, maxf(12, screen.x - width - 12))
	pos.y = clampf(pos.y, 12, maxf(12, screen.y - 77))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#0b191ef5")
	box.border_color = Color("#3b7983")
	box.set_border_width_all(1)
	draw_style_box(box, Rect2(pos, Vector2(width, 65)))
	draw_string(font, pos + Vector2(13, 25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d9fcff"))
	draw_string(font, pos + Vector2(13, 49), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a5bfc1"))
