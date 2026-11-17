class_name Minimap
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
var _fog_revision := -1
var _tex: ImageTexture
var _bg_version := -1
var _bg_seed := -1
var _meta: Dictionary
var _view := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_tex = ImageTexture.create_from_image(_frame)


static func map_pt(x: float, z: float) -> Vector2:
	return Vector2((x - CaveShape.WORLD_X0) / (CaveShape.WORLD_X1 - CaveShape.WORLD_X0) * W,
		(z - CaveShape.WORLD_Z0) / (CaveShape.WORLD_Z1 - CaveShape.WORLD_Z0) * H)


# ---------------------------------------------------------------- Dessin lissé (canvas 2D)

## fillRect lissé : chaque pixel reçoit la couleur au prorata de sa surface couverte.
static func fill_rect(img: Image, x: float, y: float, w: float, h: float, c: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	var x0 := maxi(0, floori(x))
	var x1 := mini(W, ceili(x + w))
	var y0 := maxi(0, floori(y))
	var y1 := mini(H, ceili(y + h))
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
	g.fill(Color("#233522"))
	var R := Rng.new(775)
	for i in 2400:
		var col := Color("#34472b") if R.next() > 0.5 else Color("#1b2b1e")
		var rx := R.next() * W
		var ry := R.next() * H
		fill_rect(g, rx, ry, 2.0, 2.0, col)
	var rock := Color("#3a342d")
	var x := CaveShape.WORLD_X0
	while x < CaveShape.WORLD_X1:
		var a := map_pt(x, CaveShape.WORLD_Z0)
		var c := map_pt(x + 2.0, CaveShape.mountain_edge(x + 1.0))
		fill_rect(g, a.x, a.y, c.x - a.x + 0.5, c.y - a.y, rock)
		x += 2.0
	var hollow := Color("#24262b")
	for k: Vector2i in st.dug:
		_cell(g, k.x * 4.0, k.y * 4.0, 4.0, hollow)
	x = -68.0
	while x < 68.0:
		var z := -170.0
		while z < -86.0:
			if CaveShape.in_cave(x, z):
				_cell(g, x, z, 1.5, hollow)
			z += 1.5
		x += 1.5
	if st.found > 0:
		var z := CaveShape.WORLD_Z0
		while z < CaveShape.WORLD_Z1:
			x = CaveShape.WORLD_X0
			while x < CaveShape.WORLD_X1:
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
	var pz: float = Simulation.PORTAL.y
	for d: Dictionary in _meta["deity_portals"]:
		var p := map_pt(d["x"], pz)
		fill_rect(g, p.x - 1.0, p.y, 2.0, 2.0, Color(d["color"]))
	var pp := map_pt(Simulation.PORTAL.x, pz)
	fill_rect(g, pp.x - 2.0, pp.y, 4.0, 2.0, Color("#ffc04a"))
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
	if st.version != _bg_version or st.seed != _bg_seed:
		build_background(st)
	_frame.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
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
	if _fog_revision != world.fog.revision:
		_fog_mask = world.fog.image.duplicate()
		_fog_mask.resize(W, H, Image.INTERPOLATE_BILINEAR)
		_fog_revision = world.fog.revision
	_frame.blend_rect(_fog_mask, Rect2i(0, 0, W, H), Vector2i.ZERO)
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
	fill_rect(_frame, p.x - s / 2.0, p.y - s / 2.0, s, s, c)


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
	var c := Vector2(CaveShape.WORLD_X0 + local.x / inner.size.x * (CaveShape.WORLD_X1 - CaveShape.WORLD_X0),
		CaveShape.WORLD_Z0 + local.y / inner.size.y * (CaveShape.WORLD_Z1 - CaveShape.WORLD_Z0))
	cam.set_view(c, cam.px)
	refresh()


func _gui_input(event: InputEvent) -> void:
	if world == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
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
