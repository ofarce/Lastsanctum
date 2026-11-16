class_name ReviveFx
extends Node2D
## Rappel par le Puits des Âmes (planche « Puits des Âmes · Lotus de pierre ») : une bulle d'eau verte se forme
## au sommet du jet du Lotus, flotte jusqu'à l'unité, gonfle à sa taille, se déforme jusqu'à prendre sa
## silhouette (champ de distance de l'image de repos), puis l'eau devient l'unité ; quelques gouttes tombent.
## Le sprite, l'ombre et la barre de vie de l'unité restent masqués jusqu'à la métamorphose (UnitView).
## Repère : pieds de l'unité, pixels natifs.

const FORM := 0.6
const FLIGHT := 1.5
const GROW := 2.0
const MORPH := 2.9
const SOLID := 3.5
const END := 4.0
const G := [Color("#0a2412"), Color("#0f3a1a"), Color("#1f6a2a"), Color("#3fa83a"), Color("#7ae070"), Color("#b8f0a0"), Color("#e8ffe0")]
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
## Sommet du jet du Lotus au repos, au-dessus du centre au sol de l'emprise (LOTUS.jetH + 9).
const JET_TOP := 19.0

# UnitView et AdeptView exposent des sources de sprites différentes.
var view
## Silhouettes par rôle : {sdf: PackedFloat32Array, w, h, ax, ay, c: Vector2 (centre), r: Vector2 (rayons)}.
static var _shapes := {}


static func age(u: Unit) -> float:
	return GameState.sim_time - u.revived_at


static func active(u: Unit) -> bool:
	var a := age(u)
	return a >= 0.0 and a < END


## Le sprite de l'unité réapparaît sous l'eau au moment où la silhouette est formée.
static func body_shown(u: Unit) -> bool:
	return not active(u) or age(u) >= MORPH


func tick() -> void:
	var on := active(view.unit)
	if on or visible:
		queue_redraw()
	visible = on


func _shape() -> Dictionary:
	var role: String = view.unit.role
	if _shapes.has(role):
		return _shapes[role]
	var img: Image
	var ax: float
	var ay: float
	if view is AdeptView:
		var idle: Dictionary = view._frames["idle"]
		img = idle["tex"].get_image().get_region(Rect2i(idle["rects"][0]))
		ax = view._ax
		ay = view._ay
	else:
		var frame: AtlasTexture = view._idle[0]
		img = frame.atlas.get_image().get_region(Rect2i(frame.region))
		ax = float(view._meta["ax"])
		ay = float(view._meta["ay"])
	img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var inside := PackedByteArray()
	inside.resize(w * h)
	var x0 := w
	var x1 := 0
	var y0 := h
	var y1 := 0
	for y in h:
		for x in w:
			var on := img.get_pixel(x, y).a > 0.0
			inside[y * w + x] = 1 if on else 0
			if on:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	var din := _chamfer(inside, w, h, 1)
	var dout := _chamfer(inside, w, h, 0)
	var sdf := PackedFloat32Array()
	sdf.resize(w * h)
	for i in w * h:
		sdf[i] = -(din[i] - 0.5) if inside[i] else dout[i] - 0.5
	var out := {"sdf": sdf, "w": w, "h": h, "ax": ax, "ay": ay,
		"c": Vector2((x0 + x1 + 1) / 2.0, (y0 + y1 + 1) / 2.0), "r": Vector2((x1 - x0) / 2.0 + 1.5, (y1 - y0) / 2.0 + 1.5)}
	_shapes[role] = out
	return out


## Distance de chanfrein (1, √2) de chaque pixel au plus proche pixel dont inside ≠ target.
static func _chamfer(inside: PackedByteArray, w: int, h: int, target: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0.0 if inside[i] != target else 1e6
	var r2 := sqrt(2.0)
	for y in h:
		for x in w:
			var i := y * w + x
			if x > 0: d[i] = minf(d[i], d[i - 1] + 1.0)
			if y > 0:
				d[i] = minf(d[i], d[i - w] + 1.0)
				if x > 0: d[i] = minf(d[i], d[i - w - 1] + r2)
				if x < w - 1: d[i] = minf(d[i], d[i - w + 1] + r2)
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			if x < w - 1: d[i] = minf(d[i], d[i + 1] + 1.0)
			if y < h - 1:
				d[i] = minf(d[i], d[i + w] + 1.0)
				if x < w - 1: d[i] = minf(d[i], d[i + w + 1] + r2)
				if x > 0: d[i] = minf(d[i], d[i + w - 1] + r2)
	return d


static func _bay(x: int, y: int) -> float:
	return (BAYER[posmod(y, 4)][posmod(x, 4)] + 0.5) / 16.0


func _dpx(x: float, y: float, c: Color, a: float = 1.0) -> void:
	var ix := roundi(x)
	var iy := roundi(y)
	if a <= 0.0 or (a < 1.0 and a <= _bay(ix, iy)):
		return
	draw_rect(Rect2(ix, iy, 1, 1), c)


static func _sm(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


static func _eout(v: float) -> float:
	return 1.0 - pow(1.0 - clampf(v, 0.0, 1.0), 3.0)


## Bulle ronde (formation, vol) centrée en c.
func _bubble(c: Vector2, rx: float, ry: float) -> void:
	for y in range(floori(c.y - ry), ceili(c.y + ry) + 1):
		for x in range(floori(c.x - rx), ceili(c.x + rx) + 1):
			var d := Vector2((x + 0.5 - c.x) / rx, (y + 0.5 - c.y) / ry).length()
			if d > 1.0:
				continue
			if d > 0.8:
				draw_rect(Rect2(x, y, 1, 1), G[3] if d > 0.92 else G[5])
			else:
				_dpx(x, y, G[3], 0.2)
	_dpx(c.x - rx * 0.4, c.y - ry * 0.45, G[6])
	_dpx(c.x - rx * 0.4 + 1.0, c.y - ry * 0.45, G[6])
	_dpx(c.x - rx * 0.4, c.y - ry * 0.45 + 1.0, G[5])


## Bulle qui se déforme vers la silhouette : k = 0 bulle, 1 silhouette ; fade = opacité de l'eau.
func _morph(S: Dictionary, k: float, rx: float, ry: float, lift: float, fade: float, t: float) -> void:
	var w: int = S["w"]
	var h: int = S["h"]
	var sdf: PackedFloat32Array = S["sdf"]
	var c: Vector2 = S["c"]
	var face := float(view._face)
	var ks := _sm(k)
	var mr := minf(rx, ry)
	var grid := PackedFloat32Array()
	grid.resize(w * h)
	for y in h:
		for x in w:
			var nx := (x + 0.5 - c.x) / rx
			var ny := (y + 0.5 - c.y) / ry
			var an := atan2(ny, nx)
			var wob := sin(an * 3.0 + t * 7.0) * 0.7 * (1.0 - k) + sin(an * 5.0 - t * 9.0) * 0.4 * sin(PI * k)
			grid[y * w + x] = lerpf((Vector2(nx, ny).length() - 1.0) * mr + wob, sdf[y * w + x], ks)
	for y in h:
		for x in w:
			var d := grid[y * w + x]
			if d >= 0.0:
				continue
			var edge := y == 0 or x == 0 or grid[(y - 1) * w + x] >= 0.0 or grid[y * w + x - 1] >= 0.0
			var col: Color
			var a := fade
			if d > -1.0:
				col = G[5] if edge else G[3]
			elif d > -2.2 and edge:
				col = G[4]
			else:
				col = G[3]
				a = fade * (0.18 + 0.5 * ks + (0.15 if (y + floori(t * 10.0)) % 9 == 0 else 0.0))
				if ks > 0.6 and (x + y * 2 + floori(t * 14.0)) % 11 == 0:
					col = G[5]
					a = fade * 0.7
			var lx := (x - float(S["ax"])) * face
			_dpx(lx if face > 0.0 else lx - 1.0, y - float(S["ay"]) - lift, col, a)
	var hx := (lerpf(c.x - rx * 0.4, c.x - 6.0, ks) - float(S["ax"])) * face
	var hy := lerpf(c.y - ry * 0.45, c.y - 16.0, ks) - float(S["ay"]) - lift
	_dpx(hx, hy, G[6], fade)
	_dpx(hx, hy + 1.0, G[5], fade)


func _draw() -> void:
	var u: Unit = view.unit
	var a := age(u)
	if a < 0.0 or a >= END:
		return
	var t := GameState.sim_time
	var S := _shape()
	var well: Vector2 = Proj.nat(u.revived_from.x, 0.0, u.revived_from.y) - view.position
	if view is AdeptView:
		well /= AdeptView.SCALE
	var jet := well + Vector2(0, -JET_TOP)
	var land := Vector2((float(S["c"].x) - float(S["ax"])) * view._face, float(S["c"].y) - float(S["ay"]))
	# Jet qui monte pendant la formation de la bulle.
	if a < FLIGHT:
		var surge := _sm(a / 0.3) * (1.0 - _sm((a - FORM) / 0.4))
		for i in roundi(surge * 9.0):
			_dpx(jet.x, jet.y - i, G[5] if i < 7 else G[6])
	if a < FORM:
		var r := _sm((a - 0.1) / (FORM - 0.1)) * 5.0
		if r > 0.5:
			_bubble(jet + Vector2(0, -r - 9.0 * _sm(a / 0.3)), r, r)
	elif a < FLIGHT:
		var k := _sm((a - FORM) / (FLIGHT - FORM))
		var from := jet + Vector2(0, -14)
		var p := from.lerp(land + Vector2(0, -6), k) + Vector2(0, -sin(PI * k) * 14.0 + sin(t * 9.0) * 0.6)
		_bubble(p, 5.0, 5.0)
	elif a < SOLID:
		var g1 := _eout((a - FLIGHT) / (GROW - FLIGHT))
		var R: Vector2 = S["r"]
		var rx := lerpf(5.0, R.x, g1)
		var ry := lerpf(5.0, R.y, g1)
		var k := 0.0 if a < GROW else _sm((a - GROW) / (MORPH - GROW))
		var lift := (1.0 - g1) * 6.0 if a < GROW else 0.0
		var fade := 1.0 if a < MORPH else 1.0 - _sm((a - MORPH) / (SOLID - MORPH))
		_morph(S, 1.0 if a >= MORPH else k, rx, ry, lift, fade, t)
	# Gouttes qui retombent pendant la transformation, flaque qui s'évapore.
	if a >= MORPH - 0.1:
		var b := a - (MORPH - 0.1)
		for j in 9:
			var t0 := HealFx._hash(j, 21) * 0.9
			var ag := b - t0
			if ag < 0.0 or ag > 0.5:
				continue
			var x := -9.0 + HealFx._hash(j, 22) * 20.0
			var y0 := -30.0 + HealFx._hash(j, 23) * 24.0
			var y := minf(1.0, y0 + ag * ag * 160.0)
			draw_rect(Rect2(roundi(x), roundi(y), 1, 1), G[4] if y >= 1.0 else G[5])
		var pk := clampf(b / 0.5, 0.0, 1.0) * (1.0 - _sm((a - SOLID) / 0.5))
		for y in range(-3, 4):
			for x in range(-9, 10):
				var d := Vector2(x / 9.0, y / 3.0).length()
				if d <= 1.0:
					_dpx(x, y + 1, G[3], 0.55 * pk * (1.0 - d * d * 0.6))
		var rr := 7.0 + (1.0 - pk) * 5.0
		for i in 48:
			var an := TAU * i / 48.0
			_dpx(cos(an) * rr, 1.0 + sin(an) * rr * 0.4, G[5], pk * 0.8)
