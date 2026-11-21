extends Node2D
## Surimpression à la résolution écran, au-dessus de l'éclairage et sous le HUD.
var world: World
var cell: Variant = null
var selected_cells: Array[Dictionary] = []
const SEALED_LINE := Color("#ff5548")
const SEALED_FILL := Color("#e03a2e30")


func _draw() -> void:
	if world == null:
		return
	# Bosquet pétrifié sélectionné (GameState.hud_grove) : halo doré sur ses 2 × 2 cases.
	if GameState.hud_grove != null:
		var g: Vector2i = GameState.hud_grove
		_draw_cell({"i": g.x, "j": g.y}, Color("#f3c96b"), Color("#f3c96b18"), false, 2)
	for selected: Dictionary in selected_cells:
		if world.terrain_state.seal_needed(selected["i"], selected["j"]) != "":
			_draw_cell(selected, SEALED_LINE, SEALED_FILL)
		else:
			_draw_cell(selected, Color("#f3c96b"), Color("#f3c96b22"))
	if cell != null:
		# Roche scellée (le sceau qu'il faut n'est pas acquis) : cadre rouge, elle ne se mine pas.
		if world.terrain_state.seal_needed(cell["i"], cell["j"]) != "":
			_draw_cell(cell, SEALED_LINE, SEALED_FILL, true)
		else:
			_draw_cell(cell, Color("#75eef5"), Color("#46ddec2e"), true)


func _draw_cell(target: Dictionary, line_color: Color, fill_color: Color, show_info := false, cells := 1) -> void:
	var px := float(world.camera.px)
	var origin := world.camera.project(target["i"] * 4, 0, target["j"] * 4).round()
	var rect := Rect2(origin, Vector2.ONE * 32 * cells * px)
	# Case de roche : le cadre suit son dessin (dessus remonté et paroi), pas son emprise au sol.
	if cells == 1 and world.terrain_state.rock_cell(target["i"], target["j"]):
		var span := world.terrain_state.drawn_span(target["i"], target["j"])
		var top := world.camera.project(target["i"] * 4, 0, span.x).round()
		var bottom := world.camera.project(target["i"] * 4 + 4, 0, span.y).round()
		rect = Rect2(top, bottom - top)
	draw_rect(rect, fill_color)
	draw_rect(rect, Color(line_color, 0.4), false, px)
	_draw_leds(rect, px, line_color, 2 if show_info else 1, float(target["i"] + target["j"]) * 0.37)
	for point: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1 if point.x == rect.position.x else -1
		var sy := 1 if point.y == rect.position.y else -1
		draw_line(point, point + Vector2(sx * 6 * px, 0), line_color.lightened(0.25), 2 * px)
		draw_line(point, point + Vector2(0, sy * 6 * px), line_color.lightened(0.25), 2 * px)
	if not show_info:
		return
	var block := world.terrain_state.block_definition(target["i"], target["j"])
	var font := ThemeDB.fallback_font
	var sealed := line_color == SEALED_LINE
	var title := ("Scellé : " if sealed else "Miner : ") + str(block.get("material_name", ""))
	var detail := "Clic droit · Case 4 × 4"
	var seal: String = world.terrain_state.seal_needed(target["i"], target["j"])
	if seal != "":
		detail = "Recherche « %s » requise" % Catalog.RESEARCH[seal]["name"]
	if world.terrain_state.permanent_ores.has(Vector2i(cell["i"], cell["j"])):
		detail = "Gisement inépuisable"
	var wood_key := Vector2i(cell["i"], cell["j"])
	if world.terrain_state.grove_cells.has(wood_key):
		detail = "Bosquet inépuisable · clic droit avec un adepte"
	var width := maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) + 26
	var screen := get_viewport_rect().size
	var pos := Vector2(rect.end.x + 14, rect.position.y)
	if pos.x + width > screen.x - 12:
		pos.x = rect.position.x - width - 14
	pos.x = clampf(pos.x, 12, maxf(12, screen.x - width - 12))
	pos.y = clampf(pos.y, 12, maxf(12, screen.y - 77))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#1e0d0bf5") if sealed else Color("#0b191ef5")
	box.border_color = Color("#a8443a") if sealed else Color("#3b7983")
	box.set_border_width_all(1)
	draw_style_box(box, Rect2(pos, Vector2(width, 65)))
	draw_string(font, pos + Vector2(13, 25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffd9d4") if sealed else Color("#d9fcff"))
	draw_string(font, pos + Vector2(13, 49), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d9a39c") if sealed else Color("#a5bfc1"))


## Lumière qui court sur le pourtour (sens horaire) : `waves` traînées continues par tour, dégradé lisse
## de la tête vers la queue, halo large dessous. Le chemin a des angles arrondis (quart de cercle de rayon
## CORNER × px) : un seul tracé fermé, même épaisseur partout, coins compris.
const CORE_WIDTH := 4.0
const HALO_WIDTH := 8.0
const CORNER := 4.0


func _draw_leds(rect: Rect2, px: float, color: Color, waves: int, offset: float) -> void:
	var r := CORNER * px
	# Côtés dans le sens horaire (haut, droite, bas, gauche) : le cadre d'une roche est plus haut que large.
	var sides := [rect.size.x - 2.0 * r, rect.size.y - 2.0 * r, rect.size.x - 2.0 * r, rect.size.y - 2.0 * r]
	var arc := PI * 0.5 * r
	var total := 0.0
	for side: float in sides:
		total += side + arc
	var count := int(ceil(total / 1.5))  # un échantillon tous les 1,5 pixel écran
	var centers := [Vector2(rect.end.x - r, rect.position.y + r), Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r), Vector2(rect.position.x + r, rect.position.y + r)]
	var t := Time.get_ticks_msec() / 1000.0
	var head := color.lightened(0.65)
	var points := PackedVector2Array()
	var core := PackedColorArray()
	var halo := PackedColorArray()
	for k in count + 1:
		var d := total * float(k % count) / count
		var m := 0
		while m < 3 and d >= sides[m] + arc:
			d -= sides[m] + arc
			m += 1
		var u := d
		var straight: float = sides[m]
		var dir := Vector2.RIGHT.rotated(PI * 0.5 * m)  # sens de marche du côté m
		var c: Vector2 = centers[m]
		var point: Vector2
		if u < straight:
			# Côté droit : du bout de l'arc précédent jusqu'au centre de l'arc suivant (projeté sur le bord).
			point = c - dir * (straight - u) + dir.rotated(-PI * 0.5) * r
		else:
			var a := -PI * 0.5 + PI * 0.5 * m + (u - straight) / r
			point = c + Vector2(cos(a), sin(a)) * r
		# Phase : 0 en tête, croît vers la queue ; la tête avance de 0,9 tour par seconde.
		var phase := fposmod(t * 0.9 * waves - float(k) / count * waves + offset, 1.0)
		var glow := pow(1.0 - phase, 4.0)
		points.append(point)
		core.append(Color(color, 0.0).lerp(head, glow))
		halo.append(Color(color, glow * 0.35))
	draw_polyline_colors(points, halo, HALO_WIDTH * px, true)
	draw_polyline_colors(points, core, CORE_WIDTH * px, true)
