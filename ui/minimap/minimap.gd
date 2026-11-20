class_name Minimap
## Monde procédural : la minicarte montre une fenêtre de la taille de la zone d'origine (464 × 408), qui
## suit la caméra par pas de WIN_STEP unités, bornée à la carte. Au départ, elle coïncide avec la zone
## d'origine (dessin identique au prototype) ; ailleurs, le moucheté de la jungle est ancré au monde.
extends Control
## Minicarte du HUD (buildMiniMap, drawMiniMap, hud.js, 73b410f).
## Le fond est un canvas de 240×160 dessiné comme dans le prototype : rectangles à coordonnées
## fractionnaires, lissés par couverture comme le canvas 2D. Il est refait quand le terrain change
## (creusement, galerie découverte). Les points (bâtiments, Ancre, tourelles, unités) sont ajoutés à
## chaque mise à jour du HUD ; le trapèze de la vue est tracé par-dessus. Le canvas est étiré à la taille
## du module sans lissage (image-rendering: pixelated), comme dans le prototype.
## Clic ou glisser : déplace la caméra ; flèches (minicarte active) : la décalent de 5 unités.

const W := 240
const H := 160
const META := "res://assets/baked/hud/minimap_meta.json"

var world: World
## Hauteur du bandeau de commandement, pour le bas du trapèze de vue.
var command_bar_height := 120.0

var _bg := Image.create(W, H, false, Image.FORMAT_RGBA8)
var _frame := Image.create(W, H, false, Image.FORMAT_RGBA8)
var _fog_mask: Image
## Fond déjà fondu avec le brouillard (cache), fond + points avant brouillard, rectangles des points de l'image.
var _bg_fog: Image
var _pre: Image
var _dots: Array[Rect2i] = []
var _fog_revision := -1
var _tex: ImageTexture
var _bg_version := -1
var _bg_seed := -1
var _meta: Dictionary
var _view := PackedVector2Array()
const WIN_STEP := 32.0
## Fenêtre affichée (unités du monde).
static var win := Rect2(CaveShape.START_X0, CaveShape.START_Z0, CaveShape.START_X1 - CaveShape.START_X0, CaveShape.START_Z1 - CaveShape.START_Z0)
var _bg_win := Rect2()
var _fog_win := Rect2()
var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_tex = ImageTexture.create_from_image(_frame)


static func map_pt(x: float, z: float) -> Vector2:
	return Vector2((x - win.position.x) / win.size.x * W, (z - win.position.y) / win.size.y * H)


static func start_window() -> Rect2:
	return Rect2(CaveShape.START_X0, CaveShape.START_Z0, CaveShape.START_X1 - CaveShape.START_X0, CaveShape.START_Z1 - CaveShape.START_Z0)


## Fenêtre centrée sur `c`, alignée sur WIN_STEP et bornée à la carte ; la zone d'origine tant que la
## caméra y reste.
static func window_for(c: Vector2) -> Rect2:
	var s := start_window()
	var half := s.size / 2.0
	var center := s.get_center()
	if c.x < s.position.x + half.x * 0.5 or c.x > s.end.x - half.x * 0.5 or c.y < s.position.y + half.y * 0.5:
		center = (c / WIN_STEP).round() * WIN_STEP
	var o := center - half
	o.x = clampf(o.x, CaveShape.WORLD_X0, CaveShape.WORLD_X1 - s.size.x)
	o.y = clampf(o.y, CaveShape.WORLD_Z0, CaveShape.WORLD_Z1 - s.size.y)
	return Rect2(o, s.size)


# ---------------------------------------------------------------- Dessin lissé (canvas 2D)

static func _blend_px(img: Image, px: int, py: int, x: float, y: float, w: float, h: float, c: Color) -> void:
	var cy := minf(py + 1.0, y + h) - maxf(float(py), y)
	var cx := minf(px + 1.0, x + w) - maxf(float(px), x)
	if cx <= 0.0 or cy <= 0.0:
		return
	var a := roundf(c.a * cx * cy * 255.0) / 255.0
	if a <= 0.0:
		return
	var d := img.get_pixel(px, py)
	img.set_pixel(px, py, Color(d.r + (c.r - d.r) * a, d.g + (c.g - d.g) * a, d.b + (c.b - d.b) * a))


## fillRect lissé : chaque pixel reçoit la couleur au prorata de sa surface couverte.
static func fill_rect(img: Image, x: float, y: float, w: float, h: float, c: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	var x0 := maxi(0, floori(x))
	var x1 := mini(W, ceili(x + w))
	var y0 := maxi(0, floori(y))
	var y1 := mini(H, ceili(y + h))
	# Intérieur couvert à 100 % d'une couleur opaque : remplissage natif (même résultat, a = 1).
	var ix0 := maxi(x0, ceili(x))
	var ix1 := mini(x1, floori(x + w))
	var iy0 := maxi(y0, ceili(y))
	var iy1 := mini(y1, floori(y + h))
	if c.a >= 1.0 and ix1 - ix0 >= 2 and iy1 - iy0 >= 2:
		img.fill_rect(Rect2i(ix0, iy0, ix1 - ix0, iy1 - iy0), Color(c.r, c.g, c.b))
		for py in range(y0, y1):
			var edge_row := py < iy0 or py >= iy1
			for px in range(x0, x1):
				if edge_row or px < ix0 or px >= ix1:
					_blend_px(img, px, py, x, y, w, h, c)
		return
	for py in range(y0, y1):
		var cy := minf(py + 1.0, y + h) - maxf(float(py), y)
		if cy <= 0.0:
			continue
		for px in range(x0, x1):
			var cx := minf(px + 1.0, x + w) - maxf(float(px), x)
			if cx <= 0.0:
				continue
			var a := roundf(c.a * cx * cy * 255.0) / 255.0
			if a <= 0.0:
				continue
			var d := img.get_pixel(px, py)
			img.set_pixel(px, py, Color(d.r + (c.r - d.r) * a, d.g + (c.g - d.g) * a, d.b + (c.b - d.b) * a))


## buildMiniMap : fond de la minicarte (montagne, salle, cases creusées, galeries, couloir, chemin,
## arbres, portails).
func build_background(st: TerrainState) -> void:
	var g := _bg
	_bg_win = win
	g.fill(Color("#233522"))
	if win == start_window():
		var R := Rng.new(775)
		for i in 2400:
			var col := Color("#34472b") if R.next() > 0.5 else Color("#1b2b1e")
			var rx := R.next() * W
			var ry := R.next() * H
			fill_rect(g, rx, ry, 2.0, 2.0, col)
	else:
		# Moucheté ancré au monde : un point par cellule de 8 unités, position et teinte hachées.
		var cz := floorf(win.position.y / 8.0) * 8.0
		while cz < win.end.y:
			var cx := floorf(win.position.x / 8.0) * 8.0
			while cx < win.end.x:
				var hsh := hash([cx, cz, 775])
				var q := map_pt(cx + float(hsh & 7), cz + float((hsh >> 3) & 7)).floor()
				g.fill_rect(Rect2i(int(q.x), int(q.y), 2, 2), Color("#34472b") if (hsh >> 6) & 1 else Color("#1b2b1e"))
				cx += 8.0
			cz += 8.0
		# Arbres de la jungle hors zone d'origine (mêmes couleurs que les arbres du prototype).
		cz = floorf(win.position.y / 4.0) * 4.0
		while cz < win.end.y:
			var cx := floorf(win.position.x / 4.0) * 4.0
			while cx < win.end.x:
				var hsh := hash([cx, cz, 0x7ee])
				var tx := cx + float(hsh & 3)
				var tz := cz + float((hsh >> 2) & 3)
				if not CaveShape.in_start(tx, tz) and tz > CaveShape.mountain_edge(tx) + 3.0 and (hsh >> 4) % 3 != 0:
					var q := (map_pt(tx, tz) - Vector2.ONE).floor()
					g.fill_rect(Rect2i(int(q.x), int(q.y), 2, 2), Color("#162d1c") if (hsh >> 6) & 1 else Color("#2f4c29"))
				cx += 4.0
			cz += 4.0
	var rock := Color("#3a342d")
	var x := win.position.x
	if win == start_window():
		while x < win.end.x:
			var a := map_pt(x, win.position.y)
			var c := map_pt(x + 2.0, CaveShape.mountain_edge(x + 1.0))
			fill_rect(g, a.x, a.y, c.x - a.x + 0.5, c.y - a.y, rock)
			x += 2.0
	else:
		# Montagne colonne par colonne : remplissage natif, dernier pixel mélangé au prorata.
		for px in W:
			var wx := win.position.x + (px + 0.5) / W * win.size.x
			var ey := map_pt(wx, CaveShape.mountain_edge(wx)).y
			if ey <= 0.0:
				continue
			var full := mini(H, floori(ey))
			if full > 0:
				g.fill_rect(Rect2i(px, 0, 1, full), rock)
			if full < H:
				_blend_px(g, px, full, px, 0.0, 1.0, ey, rock)
	var hollow := Color("#24262b")
	for k: Vector2i in st.dug:
		_cell(g, k.x * 4.0, k.y * 4.0, 4.0, hollow)
	x = -68.0
	while x < 68.0:
		var z := -192.0
		while z < -86.0:
			if CaveShape.in_cave(x, z):
				_cell(g, x, z, 1.5, hollow)
			z += 1.5
		x += 1.5
	if st.found > 0:
		var z := win.position.y
		while z < win.end.y:
			x = win.position.x
			while x < win.end.x:
				if st.is_gallery_open(x + 1.0, z + 1.0):
					_cell(g, x, z, 2.0, hollow)
				x += 2.0
			z += 2.0
	var e := map_pt(-CaveShape.CAVE_GATE, CaveShape.CAVE_Z1)
	var hi := map_pt(CaveShape.CAVE_GATE, CaveShape.mountain_edge(0.0))
	fill_rect(g, e.x, e.y - 1.0, hi.x - e.x, hi.y - e.y + 1.0, hollow)
	# Chemin vers le sud : trait de 3 px (extrémités droites).
	var p0 := map_pt(0.0, CaveShape.mountain_edge(0.0))
	var p1 := map_pt(0.0, 72.0)
	fill_rect(g, p0.x - 1.5, p0.y, 3.0, p1.y - p0.y, Color("#7e7956"))
	for t: Array in _meta["trees"]:
		var p := map_pt(t[0], t[1])
		fill_rect(g, p.x - 1.0, p.y - 1.0, 2.0, 2.0, Color("#162d1c") if t[2] else Color("#2f4c29"))
	_bg_version = st.version
	_bg_seed = st.seed


static func _cell(g: Image, x: float, z: float, s: float, c: Color) -> void:
	var a := map_pt(x, z)
	var b := map_pt(x + s, z + s)
	fill_rect(g, a.x, a.y, b.x - a.x + 0.4, b.y - a.y + 0.4, c)


func background() -> Image:
	return _bg


# ---------------------------------------------------------------- drawMiniMap

## Recompose la minicarte (fond, points) et le trapèze de vue.
func refresh() -> void:
	if world == null or world.terrain_state == null:
		return
	var st := world.terrain_state
	# Fenêtre figée pendant un clic-glisser sur la minicarte (elle ne bouge pas sous le curseur).
	if not _dragging:
		win = window_for(world.camera.cam)
	# Fond et brouillard ne changent qu'avec le terrain, la fenêtre ou la vue des unités : leur fondu (toute la
	# carte) est gardé en cache. À chaque rafraîchissement, seuls les rectangles des points sont refondus, à
	# partir de l'image « fond + points » : pixel pour pixel le même résultat qu'un fondu de toute la carte.
	var stale := _bg_fog == null
	if st.version != _bg_version or st.seed != _bg_seed or win != _bg_win:
		build_background(st)
		stale = true
	if _fog_revision != world.fog.revision or _fog_win != win:
		# Brouillard (toute la carte) recadré sur la fenêtre affichée.
		var o := Vector2i(int(win.position.x - CaveShape.WORLD_X0), int(win.position.y - CaveShape.WORLD_Z0))
		_fog_mask = world.fog.image.get_region(Rect2i(o, Vector2i(win.size)))
		_fog_mask.resize(W, H, Image.INTERPOLATE_BILINEAR)
		_fog_revision = world.fog.revision
		_fog_win = win
		stale = true
	if stale:
		if _bg_fog == null:
			_bg_fog = Image.create(W, H, false, Image.FORMAT_RGBA8)
			_pre = Image.create(W, H, false, Image.FORMAT_RGBA8)
		_bg_fog.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
		_bg_fog.blend_rect(_fog_mask, Rect2i(0, 0, W, H), Vector2i.ZERO)
	_pre.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
	_frame.blit_rect(_bg_fog, Rect2i(0, 0, W, H), Vector2i.ZERO)
	_dots.clear()
	for b in GameState.buildings:
		_dot(b.x, b.z, Color("#e3c685") if not b.complete else (Color("#8de8ed") if b.is_temple() else Color("#d0b376")), 4.0)
	for p: Dictionary in st.portals:
		if p.get("active", false):
			_dot(p["x"], p["z"], Color("#ff4020"), 4.0)
	_dot(CaveShape.CORE.x, CaveShape.CORE.y, Color("#d2a5ff") if GameState.orb_active else Color("#6e5a86"), 4.0)
	# Tourelles de l'entrée : éveillées avec l'Ancre (activateTurrets) ; leur état propre arrive à l'étape 8.
	for t: Dictionary in _meta["turrets"]:
		_dot(t["x"], t["z"], Color("#e3c48b") if GameState.orb_active else Color("#858d71"), 3.0)
	for u in GameState.units:
		if u.alive() and not u.hidden:
			_dot(u.x, u.z, Color("#ffe0a0") if GameState.selected.has(u) else Color("#a8cc7b"), 3.0)
	for e: Variant in GameState.enemies:
		if not e.hidden:
			_dot(e.x, e.z, Color("#ee7055"), 3.0)
	for r: Rect2i in _dots:
		_frame.blit_rect(_pre, r, r.position)
		_frame.blend_rect(_fog_mask, r, r.position)
	# Iris de la Matrice (module d'exo) : les ennemis hors de vue se voient à travers la roche, en cyan.
	if Loot.iris_worn():
		for e: Variant in GameState.enemies:
			if not e.hidden and e.hp > 0.0 and not world.fog.visible_at(Vector2(e.x, e.z)):
				var q := map_pt(e.x, e.z)
				if q.x >= 1.0 and q.y >= 1.0 and q.x < W - 2.0 and q.y < H - 2.0:
					fill_rect(_frame, q.x - 1.0, q.y - 1.0, 2.0, 2.0, Color("#5fd8e8"))
	_tex.update(_frame)
	# Trapèze : coins de l'écran au-dessus du bandeau, projetés au sol.
	var cam := world.camera
	var ss := cam.screen_size()
	var bottom := ss.y - command_bar_height - 18.0
	_view = PackedVector2Array()
	for s in [Vector2.ZERO, Vector2(ss.x, 0), Vector2(ss.x, bottom), Vector2(0, bottom)]:
		var gp := cam.ground_from_screen(s)
		_view.append(map_pt(gp.x, gp.y))
	queue_redraw()


func _dot(x: float, z: float, c: Color, s: float) -> void:
	if not world.fog.visible_at(Vector2(x, z)):
		return
	var p := map_pt(x, z)
	fill_rect(_pre, p.x - s / 2.0, p.y - s / 2.0, s, s, c)
	# Pixels touchés par fill_rect (mêmes bornes), à refondre avec le brouillard.
	var x0 := maxi(0, floori(p.x - s / 2.0))
	var y0 := maxi(0, floori(p.y - s / 2.0))
	var x1 := mini(W, ceili(p.x - s / 2.0 + s))
	var y1 := mini(H, ceili(p.y - s / 2.0 + s))
	if x1 > x0 and y1 > y0:
		_dots.append(Rect2i(x0, y0, x1 - x0, y1 - y0))


func frame_image() -> Image:
	return _frame


func _draw() -> void:
	# Bordure de 1 px (#minimap), puis le canvas étiré à l'intérieur.
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("#6d5a34"), false, 1.0)
	var inner := r.grow(-1.0)
	draw_texture_rect(_tex, inner, false)
	if _view.size() == 4:
		var k := inner.size / Vector2(W, H)
		var pts := PackedVector2Array()
		for p in _view:
			pts.append(inner.position + p * k)
		# Le trapèze peut sortir de la carte : on le découpe au cadre.
		var clip := Geometry2D.intersect_polygons(pts, PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]))
		for poly in clip:
			draw_colored_polygon(poly, Color("#fff1be0d"))
		var closed := pts.duplicate()
		closed.append(pts[0])
		for i in 4:
			var seg := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([closed[i], closed[i + 1]]),
				PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]))
			for s in seg:
				draw_polyline(s, Color("#f4e0a6cc"), 1.0)


# ---------------------------------------------------------------- Navigation

func _pan(local: Vector2) -> void:
	var inner := Rect2(Vector2.ZERO, size)
	var cam := world.camera
	var c := win.position + local / inner.size * win.size
	cam.set_view(c, cam.px)
	refresh()


func _gui_input(event: InputEvent) -> void:
	if world == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		refresh()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		_dragging = true
		_pan(event.position)
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_pan(event.position)
		accept_event()
	elif event is InputEventKey and event.pressed:
		var d: Vector2 = {KEY_LEFT: Vector2(-5, 0), KEY_RIGHT: Vector2(5, 0), KEY_UP: Vector2(0, -5), KEY_DOWN: Vector2(0, 5)}.get(event.keycode, Vector2.ZERO)
		if d != Vector2.ZERO:
			world.camera.set_view(world.camera.cam + d, world.camera.px)
			refresh()
			accept_event()
