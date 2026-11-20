class_name AnchorView
extends Node2D
## L'Ancre tyrienne (planches/ancre-style-propositions.html, mélange retenu le 2026-11-19 : « la Sphère
## enchaînée au-dessus du Puits d'ombre »), dessinée en pixels natifs du monde, rendu 16 bits en aplats.
## Une margelle d'ardoise au ras du sol, pleine d'une ombre liquide ; quatre bornes à cabochon de quartz et
## quatre chaînes de fer retiennent la sphère par un cerclage.
##
## États : éteinte (sphère à demi noyée, chaînes molles), réveil (elle s'arrache du puits en tirant un fil
## d'ombre à mesure que l'Ingénieur la réactive, les chaînes se tendent), active (elle flotte, rides
## pourpres dans le puits, gouttes d'ombre qui remontent, éclairs le long des maillons ; les arcs autour
## de la sphère restent ceux d'OrbArcs). Surcharge (sim/overload.gd) : la sphère se soulève encore et les
## chaînes rompent une à une (deux segments de l'ancien anneau par chaîne), puis se renouent.
##
## Deux nœuds : `ground` = vrai sous les sprites (ombre, halo, puits) ; l'autre, enfant du porteur trié de
## l'orbe, pour les bornes, les chaînes et la sphère. Repère de dessin : centre du puits au sol en (0, 0).

## Ligne de tri (unités de monde au sud du centre) : juste devant les bornes avant.
const FRONT := 1.5
const R := 10
## Hauteur du centre de la sphère au-dessus du puits : éteinte, puis gain une fois éveillée (px natifs).
const SUNK := 2.0
const RISE := 22.0
const WELL := Vector2(25.0, 11.5)
const POOL := Vector2(17.0, 7.8)
## Pied des bornes (arrière gauche, arrière droite, avant gauche, avant droite).
const BORNES: Array[Vector2] = [Vector2(-25, -9), Vector2(25, -9), Vector2(-29, 10), Vector2(29, 10)]

const S: Array[Color] = [Color("#1c1f27"), Color("#2f3440"), Color("#444b5a"), Color("#5d6678"), Color("#7c869a"), Color("#a3adbf")]
const I: Array[Color] = [Color("#15161b"), Color("#282a33"), Color("#3d404c"), Color("#585c6b"), Color("#8a8f9f")]
const Q: Array[Color] = [Color("#8f8a80"), Color("#c9c4b6"), Color("#efeadc")]
const ON: Array[Color] = [Color("#06040a"), Color("#120a1c"), Color("#2a1340"), Color("#6a2a90"), Color("#c070e8"), Color("#f2d8ff")]
const OFF: Array[Color] = [Color("#0a0a0d"), Color("#141419"), Color("#202027"), Color("#33333d"), Color("#55555f"), Color("#85858f")]
const P_DK := Color("#2a1340")
const P_MID := Color("#6a2a90")
const P_HI := Color("#9a3ab8")
const P_HOT := Color("#c884ee")
const P_CORE := Color("#f2d8ff")
const LIQ := Color("#07050b")
const OUT := Color("#08060c")

var ground := false
## Sprite de l'orbe (masqué) : son matériau porte encore le survol posé par les commandes.
var orb: Sprite2D

static var _tex := {}


func _ready() -> void:
	if _tex.is_empty():
		_bake()
	if ground:
		return
	var arcs := OrbArcs.new()
	arcs.name = "Arcs"
	arcs.center_fn = func() -> Vector2: return _origin() + Vector2(0.0, roundf(sphere_y()))
	add_child(arcs)


func _process(_delta: float) -> void:
	queue_redraw()


# ---------- état ----------

## Éveil de l'Ancre : 0 éteinte, 0…1 pendant la réactivation, 1 active.
static func level() -> float:
	if GameState.orb_active:
		return 1.0
	return clampf(GameState.orb_progress / OrbArcs.ORB_TIME, 0.0, 1.0)


static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## Ordonnée du centre de la sphère par rapport au centre du puits (px natifs, négatif = plus haut).
static func sphere_y() -> float:
	var p := level()
	return -SUNK - _ease(p) * RISE + sin(GameState.sim_time * 1.5) * 1.2 * p - Overload.sphere_lift()


## Centre du puits et centre de la sphère, en pixels natifs du monde.
static func well_native() -> Vector2:
	return Proj.nat(CaveShape.CORE.x, 0.0, CaveShape.CORE.y)


static func sphere_native() -> Vector2:
	return well_native() + Vector2(0.0, sphere_y())


## Chaîne k rompue (ou dans son éclat) pendant la surcharge : deux segments de l'ancien anneau par chaîne.
static func _chain_bit(k: int, flash: bool) -> bool:
	var m := Overload.ring_mask(flash)
	if flash:
		return ((m >> (2 * k)) & 3) != 0
	return ((m >> (2 * k + 1)) & 1) != 0


func _origin() -> Vector2:
	if ground:
		return well_native().round()
	return Vector2(0.0, roundf(-8.0 * FRONT))


static func _h(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)


# ---------- dessin ----------

func _px(o: Vector2, x: float, y: float, c: Color, a := 1.0) -> void:
	draw_rect(Rect2(o + Vector2(roundf(x), roundf(y)), Vector2.ONE), Color(c, c.a * a))


## Ellipse pleine, une bande par ligne.
func _el(o: Vector2, cy: float, rx: float, ry: float, c: Color) -> void:
	var n := floori(ry)
	for y in range(-n, n + 1):
		var w := roundf(rx * sqrt(maxf(0.0, 1.0 - float(y * y) / (ry * ry))))
		if w > 0.0:
			draw_rect(Rect2(o + Vector2(-w, roundf(cy) + y), Vector2(w * 2.0 + 1.0, 1.0)), c)


func _draw() -> void:
	var o := _origin()
	var p := level()
	var t := GameState.sim_time
	if ground:
		_draw_ground(o, p, t)
	else:
		_draw_top(o, p, t)


func _draw_ground(o: Vector2, p: float, t: float) -> void:
	_el(o, 4.0, 28.0, 12.0, Color(0, 0, 0, 0.28))
	if p > 0.0:
		var a := 0.06 * p * (1.0 + 0.25 * sin(t * 3.0))
		for k: float in [1.0, 0.72, 0.45]:
			_el(o, 0.0, 40.0 * k, 18.0 * k, Color(P_HI, a))
	draw_texture(_tex["well"], o - Vector2(28, 14))
	if p <= 0.0:
		return
	# Rides pourpres qui s'élargissent dans l'ombre liquide.
	for k in 3:
		var rr := fmod(t * 0.45 + k / 3.0, 1.0)
		var c := P_MID.lerp(LIQ, minf(1.0, rr * 0.9 + 0.1 * (1.0 - p)))
		for i in 60:
			var g := i / 60.0 * TAU
			var x := roundf(cos(g) * rr * 15.0)
			var y := roundf(2.5 + sin(g) * rr * 4.6)
			var dx := x / POOL.x
			var dy := y / POOL.y
			if dx * dx + dy * dy < 0.92 and dy > -0.1:
				_px(o, x, y, c)


func _draw_top(o: Vector2, p: float, t: float) -> void:
	var e := _ease(p)
	var on := GameState.orb_active
	var cy := roundf(sphere_y())
	var sag := (1.0 - e) * 5.0 + 0.5
	var vib := sin(t * 31.0) * 0.6 if on else 0.0
	var att: Array[Vector2] = [Vector2(-8, cy - 2), Vector2(8, cy - 2), Vector2(-9, minf(cy + 3, 1)), Vector2(9, minf(cy + 3, 1))]
	for k in 2:
		_borne(o, k, p, t, on)
		_chain(o, k, att[k], sag * 0.5, vib)
	# Fil d'ombre tiré du puits par la sphère.
	if e > 0.04:
		var y0 := int(cy) + R - 1
		for y in range(y0, 3):
			var k := float(y - y0) / maxf(1.0, 2.0 - y0)
			var w := 2 if k < 0.25 or k > 0.85 else 1
			var x := roundi(sin(y * 0.5 + t * 3.0) * 0.7 * k * (1.0 - k) * 4.0)
			var c := P_DK if posmod(y + floori(t * 6.0), 5) == 0 and p > 0.5 else LIQ
			draw_rect(Rect2(o + Vector2(x - (w >> 1), y), Vector2(w, 1)), c)
	# Sphère : la partie sous la surface du puits reste noyée.
	var rows := clampi(2 - (int(cy) - 11), 0, 23)
	var bright := 1.0
	if orb and not on and (orb.material as ShaderMaterial).get_shader_parameter("hovered"):
		bright = 1.5
	var at := Rect2(o + Vector2(-11, cy - 11), Vector2(23, rows))
	var src := Rect2(0, 0, 23, rows)
	if p < 1.0:
		draw_texture_rect_region(_tex["off"], at, src, Color(bright, bright, bright * 1.05))
	if p > 0.0:
		draw_texture_rect_region(_tex["on"], at, src, Color(1, 1, 1, p))
		# Reflet pourpre qui se promène sur la sphère.
		var g := Vector2(cos(t * 0.7) * 3.5, 1.5 + sin(t * 0.9) * 3.0)
		if cy + g.y <= 0.0:
			_px(o, g.x, cy + g.y, ON[2], p)
			_px(o, g.x + 1.0, cy + g.y, ON[2], p)
	# Cerclage de fer (moitié avant).
	for i in 21:
		var g := i / 20.0 * PI
		var x := cos(g) * R
		var y := cy + 1.0 + sin(g) * 2.8
		if roundf(y) + 1.0 > 1.0:
			continue
		_px(o, x, y, I[4] if i > 14 else I[3] if i > 7 else I[1])
		_px(o, x, y + 1.0, I[3] if i > 14 else I[1])
	for k in [2, 3]:
		_chain(o, k, att[k], sag, -vib)
		_borne(o, k, p, t, on)
	if p <= 0.0:
		return
	# Gouttes d'ombre qui remontent du puits vers la sphère.
	if p > 0.3:
		for k in 6:
			var u := fmod(t * 0.35 + _h(k * 3.7), 1.0)
			var x := (_h(k * 5.1) - 0.5) * 26.0 * (1.0 - u * 0.75)
			var y := 3.0 - u * (3.0 - cy)
			_px(o, x, y + 1.0, P_HI, 0.55)
			_px(o, x, y, Color("#0a0510"))
	# Éclairs le long des maillons.
	if on:
		for k in 4:
			var ep := floorf(t * 4.0 + k * 0.6)
			if _chain_bit(k, false) or _h(k * 9.1 + ep) >= 0.32:
				continue
			var top := BORNES[k] + Vector2(0, -11)
			var pts := PackedVector2Array()
			var n := 6
			var f := floorf(t * 13.0)
			var d := top - att[k]
			var nrm := Vector2(-d.y, d.x).normalized()
			for j in n + 1:
				var u := float(j) / n
				pts.append(o + att[k] + d * u + nrm * (_h(k * 7.3 + f * 1.7 + j * 3.1) - 0.5) * 4.0 * sin(u * PI))
			PixelDraw.plot_path(self, pts, Color(PixelDraw.ORB_ARC["glow"], 0.6), true)
			PixelDraw.plot_path(self, pts, PixelDraw.ORB_ARC["core"] if _h(ep + k) > 0.6 else PixelDraw.ORB_ARC["hot"], false)


func _borne(o: Vector2, k: int, p: float, t: float, on: bool) -> void:
	var b := BORNES[k]
	draw_texture(_tex["borne"], o + b - Vector2(4, 12))
	var c := Q[1]
	if on:
		c = P_CORE if sin(t * 5.0 + k) > 0.0 else P_HOT
	elif p > 0.0:
		c = Q[1].lerp(P_HI, p)
	draw_rect(Rect2(o + b + Vector2(-1, -5), Vector2(2, 2)), c)


## Chaîne de la borne k au cerclage ; rompue, il n'en reste qu'un bout à chaque extrémité.
func _chain(o: Vector2, k: int, to: Vector2, sag: float, vib: float) -> void:
	var from := BORNES[k] + Vector2(0, -11)
	var flash := _chain_bit(k, true)
	if _chain_bit(k, false):
		for i in 6:
			_px(o, from.x + (1.0 if k % 2 == 0 else -1.0) * minf(i, 2.0), from.y + i, I[4] if i % 3 == 1 else I[2])
		for i in 5:
			_px(o, to.x, to.y + i, I[4] if i % 3 == 1 else I[2])
		return
	var n := maxi(4, roundi(from.distance_to(to) + sag))
	for pass_i in 2:
		for i in n + 1:
			var u := float(i) / n
			var b := 4.0 * u * (1.0 - u)
			var q := from.lerp(to, u) + Vector2(0.0, b * (sag + vib))
			if pass_i == 0:
				_px(o, q.x, q.y + 1.0, OUT)
			else:
				_px(o, q.x, q.y, P_CORE if flash else I[1] if i % 3 == 0 else I[4] if i % 3 == 1 else I[3])


# ---------- textures fixes, cuites une fois ----------

static func _bake() -> void:
	# Puits : margelle à douze pierres, tranche, paroi du fond et ombre liquide. Origine (28, 14).
	var well := {}
	_fill(well, 0.0, 2.0, WELL, func(dx: float, _dy: float) -> Variant:
		return S[2] if dx < -0.4 else S[0] if dx > 0.6 else S[1])
	_fill(well, 0.0, 0.0, WELL, func(dx: float, dy: float) -> Variant:
		var d := dx * dx + dy * dy
		if d < 0.46:
			return null
		if fmod((atan2(dy, dx) / TAU + 1.0) * 12.0, 1.0) < 0.08:
			return S[1]
		if dx + dy < -0.3:
			return S[5] if d > 0.8 else S[4]
		return S[2] if dx + dy > 0.55 else S[3])
	_fill(well, 0.0, 0.0, POOL, func(_dx: float, dy: float) -> Variant:
		return S[0] if dy < -0.5 else S[1] if dy < -0.15 else LIQ)
	_tex["well"] = _texture(well, Vector2i(56, 30), Vector2i(28, 14))
	# Borne d'ardoise à anneau de fer. Origine (4, 12) = pied.
	var borne := {}
	for y in range(-8, 1):
		for x in range(-3, 3):
			borne[Vector2i(x, y)] = S[4] if x < -1 else S[1] if x == 2 else S[2]
	for y in [-10, -9]:
		for x in range(-3, 3):
			borne[Vector2i(x, y)] = S[4] if x > 0 else S[5]
	borne[Vector2i(0, -11)] = I[4]
	borne[Vector2i(-1, -11)] = I[2]
	_tex["borne"] = _texture(borne, Vector2i(8, 14), Vector2i(4, 12))
	# Sphère noire, éteinte (grise) et éveillée (reflets pourpres, liseré en bas à droite). Origine (11, 11).
	for lit: bool in [false, true]:
		var pal := ON if lit else OFF
		var sph := {}
		_fill(sph, 0.0, 0.0, Vector2(R, R), func(dx: float, dy: float) -> Variant:
			var d2 := dx * dx + dy * dy
			var l := -dx * 0.5 - dy * 0.62 + sqrt(maxf(0.0, 1.0 - d2)) * 0.6
			var k := 5 if l > 0.975 else 4 if l > 0.92 else 3 if l > 0.83 else 2 if l > 0.66 else 1 if l > 0.25 else 0
			if lit and dx * 0.62 + dy * 0.72 > 0.76 and d2 > 0.6:
				k = maxi(k, 3)
			return pal[k])
		_tex["on" if lit else "off"] = _texture(sph, Vector2i(23, 23), Vector2i(11, 11))


static func _fill(buf: Dictionary, cx: float, cy: float, r: Vector2, f: Callable) -> void:
	for y in range(floori(cy - r.y), ceili(cy + r.y) + 1):
		for x in range(floori(cx - r.x), ceili(cx + r.x) + 1):
			var dx := (x - cx) / r.x
			var dy := (y - cy) / r.y
			if dx * dx + dy * dy <= 1.0:
				var c: Variant = f.call(dx, dy)
				if c != null:
					buf[Vector2i(x, y)] = c


## Tampon → texture, avec le contour coloré (teinte voisine assombrie) autour de la matière.
static func _texture(buf: Dictionary, size: Vector2i, origin: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var q := Vector2i(x, y) - origin
			if buf.has(q):
				img.set_pixel(x, y, buf[q])
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if buf.has(q + d):
					img.set_pixel(x, y, (buf[q + d] as Color).lerp(OUT, 0.72))
					break
	return ImageTexture.create_from_image(img)
