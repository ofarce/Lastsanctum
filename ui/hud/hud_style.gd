class_name HudStyle
extends RefCounted
## Direction artistique du HUD (hud.css, dialogue.css, 73b410f) : charbon et laiton.
## Couleurs, polices (Noto Serif, décision D7), icônes SVG d'origine rastérisées à la taille voulue,
## et dessin des panneaux métalliques (fond en dégradé, liseré doré, anneaux intérieurs, coins).

const GOLD := Color("#ae8546")
const GOLD_LIGHT := Color("#e6c889")
const IVORY := Color("#eee3c9")
const MUTED := Color("#b8ad93")
const INK := Color("#101511")

const MINING_SEAL := preload("res://assets/ui/mining_seal.png")
const ICONS_JSON := "res://assets/baked/overlay/hud_icons.json"

static var _regular: Font
static var _italic: Font
static var _spaced := {}
static var _icons := {}
static var _icon_src := {}


static func font() -> Font:
	if _regular == null:
		_regular = _load_font("res://assets/fonts/NotoSerif-Regular.ttf")
	return _regular


static func italic() -> Font:
	if _italic == null:
		_italic = _load_font("res://assets/fonts/NotoSerif-Italic.ttf")
	return _italic


## Police avec espacement des lettres (letter-spacing des surtitres).
static func spaced(px: int) -> Font:
	if not _spaced.has(px):
		var v := FontVariation.new()
		v.base_font = font()
		v.spacing_glyph = px
		_spaced[px] = v
	return _spaced[px]


static func _load_font(path: String) -> Font:
	var f: FontFile = load(path)
	# Repli pour les signes absents de Noto Serif (★, ▸), comme le repli du navigateur.
	var fallback: FontFile = load("res://assets/fonts/DejaVuSans.ttf")
	f.fallbacks = [fallback]
	return f


## Icônes ajoutées après le prototype (même grille 24×24) : portée et Œil qui veille.
const EXTRA_ICONS := {
	"menace": '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><path d="m12 8 2 4-2 4-2-4Z M5 3l2 3m10 0 2-3"/>',
	"range": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/><path d="M12 1v6m0 10v6M1 12h6m10 0h6"/>',
}


## Icône SVG du prototype (HUD_ICONS), en blanc, à teinter avec modulate. `filled` : remplie (cœur de
## la barre de vie) ; `stroke` : épaisseur du trait en unités de la grille 24×24.
static func icon(name: String, px: int, stroke := 1.5, filled := false) -> Texture2D:
	var key := "%s|%d|%s|%s" % [name, px, stroke, filled]
	if _icons.has(key):
		return _icons[key]
	if name == "mining_seal":
		# Respecter les 18 px du HUD et conserver la texture entre les dessins.
		var image := MINING_SEAL.get_image()
		image.resize(px, px, Image.INTERPOLATE_NEAREST)
		var texture := ImageTexture.create_from_image(image)
		_icons[key] = texture
		return texture
	if _icon_src.is_empty():
		_icon_src = JSON.parse_string(FileAccess.get_file_as_string(ICONS_JSON))["icons"]
	var body: String = EXTRA_ICONS.get(name, _icon_src.get(name, _icon_src["rune"]))
	var paint := 'fill="#fff" stroke="none"' if filled else \
		'fill="none" stroke="#fff" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"' % stroke
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" %s>%s</svg>' % [paint, body]
	var img := Image.new()
	img.load_svg_from_string(svg, px / 24.0)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


## Dégradé linéaire CSS (angle en degrés, 0 = vers le haut, 90 = vers la droite) dans `rect`.
static func linear_gradient(ci: CanvasItem, rect: Rect2, deg: float, stops: Array) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
	g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1]))
	var a := deg_to_rad(deg)
	var dir := Vector2(sin(a), -cos(a))
	# Longueur de la ligne de dégradé CSS : |w·sin a| + |h·cos a|.
	var half := (absf(rect.size.x * dir.x) + absf(rect.size.y * dir.y)) / 2.0
	var c := rect.get_center()
	var p0 := c - dir * half
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var cols := PackedColorArray()
	for p in pts:
		cols.append(g.sample(clampf((p - p0).dot(dir) / (2.0 * half), 0.0, 1.0)))
	# Quatre sommets suffisent pour deux arrêts ; au-delà, on découpe en bandes.
	if stops.size() <= 2:
		ci.draw_polygon(pts, cols)
		return
	var n := 24
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		_band(ci, rect, p0, dir, half, t0, t1, g)


static func _band(ci: CanvasItem, rect: Rect2, p0: Vector2, dir: Vector2, half: float, t0: float, t1: float, g: Gradient) -> void:
	# Bande perpendiculaire à la direction, découpée au rectangle.
	var normal := Vector2(-dir.y, dir.x)
	var big := rect.size.length()
	var a := p0 + dir * (2.0 * half * t0)
	var b := p0 + dir * (2.0 * half * t1)
	var quad := PackedVector2Array([a - normal * big, b - normal * big, b + normal * big, a + normal * big])
	var clip := Geometry2D.intersect_polygons(quad, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	var col := g.sample((t0 + t1) / 2.0)
	for poly in clip:
		ci.draw_colored_polygon(poly, col)


## Panneau métallique (.metal-panel, .hud-module) : fond, liseré doré, anneaux intérieurs, coins.
static func metal_panel(ci: CanvasItem, size: Vector2) -> void:
	var r := Rect2(Vector2.ZERO, size)
	linear_gradient(ci, r, 110.0, [[0.0, Color("#111610f5")], [1.0, Color("#0b0e0df7")]])
	_soft_top_glow(ci, r)
	_ring(ci, r.grow(-1.0), 3.0, Color("#0c100f"))
	_ring(ci, r.grow(-4.0), 1.0, Color("#7c603138"))
	_ring(ci, r, 1.0, GOLD)
	corners(ci, r.grow(-6.0))


## Halo clair en haut du panneau : radial-gradient(ellipse at 40% 0, #22251d99, transparent 75%).
static func _soft_top_glow(ci: CanvasItem, r: Rect2) -> void:
	var c := Vector2(r.size.x * 0.4, 0.0)
	# Rayons de l'ellipse « farthest-corner » : ratio des distances aux coins, × √2.
	var radii := Vector2(maxf(c.x, r.size.x - c.x), r.size.y) * sqrt(2.0)
	var steps := 16
	for i in steps:
		var t := 1.0 - float(i) / steps
		var a := 0.6 * (1.0 - clampf(t / 0.75, 0.0, 1.0))
		if a <= 0.0:
			continue
		var pts := PackedVector2Array()
		for k in 48:
			var ang := TAU * k / 48.0
			var p := c + Vector2(cos(ang) * radii.x * t, sin(ang) * radii.y * t)
			pts.append(Vector2(clampf(p.x, 0.0, r.size.x), clampf(p.y, 0.0, r.size.y)))
		ci.draw_colored_polygon(pts, Color(Color("#22251d"), a / steps * 1.6))


## Cadre intérieur d'épaisseur `w`, collé au bord de `r`.
static func _ring(ci: CanvasItem, r: Rect2, w: float, c: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), c)
	ci.draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), c)
	ci.draw_rect(Rect2(r.position.x, r.position.y + w, w, r.size.y - 2.0 * w), c)
	ci.draw_rect(Rect2(r.end.x - w, r.position.y + w, w, r.size.y - 2.0 * w), c)


static func ring(ci: CanvasItem, r: Rect2, w: float, c: Color) -> void:
	_ring(ci, r, w, c)


## Coins décoratifs (dégradés à 135° et 315° de 2 px dans des cases de 11 px) : petits triangles.
static func corners(ci: CanvasItem, r: Rect2) -> void:
	var l := 2.0 * sqrt(2.0)
	ci.draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(l, 0), r.position + Vector2(0, l)]), GOLD_LIGHT)
	ci.draw_colored_polygon(PackedVector2Array([r.end, r.end - Vector2(l, 0), r.end - Vector2(0, l)]), GOLD)


## Petit losange de liaison entre deux modules (.hud-module:after).
static func diamond(ci: CanvasItem, center: Vector2) -> void:
	var d := 3.5
	var pts := PackedVector2Array([center + Vector2(0, -d), center + Vector2(d, 0), center + Vector2(0, d), center + Vector2(-d, 0)])
	ci.draw_colored_polygon(pts, Color("#0b100d"))
	pts.append(pts[0])
	ci.draw_polyline(pts, GOLD, 1.0, true)


## Largeur d'une chaîne dans une police donnée.
static func text_width(text: String, size: int, f: Font = null) -> float:
	return (f if f else font()).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Label prêt à l'emploi : police, taille, couleur, ombre facultative.
static func label(size: int, color: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", f if f else font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
