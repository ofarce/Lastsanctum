class_name OrbitGateView
extends Node2D
## Porte de l'Orbite aux deux veilleuses (sim/orbit_gate.gd, planches/porte-boss-veilleuses.html) : façade de 96 × 49 px
## natifs posée sur la face sud de la porte « mb2 », en définition ×2 (un point = un demi-pixel natif). Herse sous un arc
## surbaissé, une niche dans chaque jambage avec un moine agenouillé qui tient une coupe allumée (or à l'ouest pour
## l'Archiprêtre, améthyste à l'est pour la Martyre), rigole gravée de chaque flamme jusqu'au losange de la clef de
## voûte. La rigole qui arrive du sol (OrbitRillView) remonte la paroi sous la niche puis la robe du moine.
## À la chute d'un gardien : sa rigole s'éteint depuis l'arène (DRAIN s), la flamme s'emballe, vacille et meurt, puis
## l'arc se vide. Porte ouverte : la herse remonte cran par cran et le fond s'éclaire.
## Repère local : x vers l'est, y vers le bas, en points (P px natifs) ; (0, 0) = milieu du pied de la face.

const P := 0.5
const FACE_TOP := -98
const HALF := 96
## Embrasure : rectangle sous l'arc, arc en demi-ellipse au-dessus de SPRING.
const AP_RX := 60.0
const AP_RY := 34.0
const SPRING := -44.0
const RING_RX := 72.0
const RING_RY := 46.0
const GROOVE_RX := 68.0
const GROOVE_RY := 42.0
const NICHE_C := 84
## Rebord de la niche ; le moine fait 28 points au-dessus, la coupe est 26 points plus haut.
const SILL := -16
const BOWL := SILL - 26
## Chronologie d'une chute (s) : rigole qui s'éteint, flamme qui s'emballe puis vacille, arc qui se vide.
const DRAIN := 2.5
const FLARE := 0.3
const GUTTER := 0.6
## Même chiffre que OrbitGate.OPEN_DELAY : la porte s'ouvre quand la dernière flamme est morte.
const OUT_AT := DRAIN + FLARE + GUTTER
const ARCH_DRAIN := 0.5
## Flot des rigoles : vitesse et écart des battements, en px natifs.
const FLOW_V := 16.0
const FLOW_GAP := 10.0
## Herse : 40 crans de 2 points, un toutes les NOTCH s, après HERSE_DELAY.
const NOTCH := 0.06
const NOTCHES := 40
const HERSE_DELAY := 0.7

const FACE := [Color("#141821"), Color("#232a36"), Color("#333944"), Color("#454b55"), Color("#575d66"), Color("#6c717a"), Color("#858a92")]
const STONE := [Color("#1c1b17"), Color("#2c2c27"), Color("#3d3d35"), Color("#525046"), Color("#6a6858"), Color("#85826d"), Color("#a29e85"), Color("#c0bba0"), Color("#dad4b8")]
const DARK := [Color("#05040a"), Color("#0e1016"), Color("#141821"), Color("#1a1f29"), Color("#232a36")]
const IRON := [Color("#0b0c10"), Color("#16181e"), Color("#232830"), Color("#363c48"), Color("#4f5666"), Color("#6c7484"), Color("#9aa2b2"), Color("#c4ccd8")]
const GOLD := [Color("#2a1c08"), Color("#4a3410"), Color("#6e4e18"), Color("#946c24"), Color("#b98c34"), Color("#ddb457"), Color("#f0d68a"), Color("#fff2c0"), Color("#ffffff")]
const AME := [Color("#180a22"), Color("#2c1440"), Color("#45205e"), Color("#62307e"), Color("#8048a0"), Color("#a062c0"), Color("#c890e0"), Color("#ecd0f8"), Color("#ffffff")]
const CRIM := [Color("#05040a"), Color("#140308"), Color("#2a0610"), Color("#4a0c1a"), Color("#781832"), Color("#a82838"), Color("#d04040"), Color("#f07850")]
const ASH := [Color("#1a1a1e"), Color("#2e2e34"), Color("#46464e"), Color("#64646c"), Color("#8a8a92"), Color("#b4b4ba"), Color("#dcdce0")]
const WHITE := [Color("#f0d68a"), Color("#fff2c0"), Color("#ffffff")]
const LIGHT := {"a": Color("#ddb457"), "m": Color("#a062c0")}

var world: World
## Milieu et pied de la face, en unités.
var at := Vector2.ZERO
## Longueur de chaque rigole au sol (px natifs), posée par OrbitRillView ; la montée sur la face la prolonge.
var rill_len := {"a": 0.0, "m": 0.0}
var _base: ImageTexture
var _arch := {}
var _climb := {}
var _dead_at := {"a": NAN, "m": NAN}
var _open_at := NAN
var _glow := Node2D.new()


func setup(w: World) -> void:
	world = w
	name = "PorteOrbite"
	var f := OrbitGate.face(w.terrain_state)
	at = Vector2(f["x"], f["z"])
	position = Proj.nat(at.x, 0.0, at.y).round() + Vector2(0, 0.5)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for k: String in ["a", "m"]:
		_arch[k] = _arch_path(k)
		_climb[k] = _climb_path(k)
	_base = _make_base()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.name = "Lueurs"
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _ready() -> void:
	if world != null and world.lighting != null:
		world.lighting.providers.append(_lights)


func _exit_tree() -> void:
	if world != null and world.lighting != null:
		world.lighting.providers.erase(_lights)


func _process(_delta: float) -> void:
	var st := world.terrain_state if world != null else null
	if st == null:
		return
	for k: String in ["a", "m"]:
		_dead_at[k] = OrbitGate.down_at(st, k)
	var open: bool = st.doors_closed.has(OrbitGate.KEY) and not st.doors_closed[OrbitGate.KEY]
	_open_at = NAN if not open else (OrbitGate.opened_at if not is_nan(OrbitGate.opened_at) else -1e6)
	var r := get_viewport_rect().grow(200.0)
	if r.has_point(get_global_transform_with_canvas().origin):
		queue_redraw()
		_glow.queue_redraw()


## Temps depuis la chute du gardien `k` (−1 en vie).
func age(k: String) -> float:
	return -1.0 if is_nan(_dead_at[k]) else GameState.sim_time - _dead_at[k]


func open_age() -> float:
	return -1.0 if is_nan(_open_at) else GameState.sim_time - _open_at


## Longueur totale (px natifs) du flot de `k` : rigole au sol puis montée sur la face.
func flow_len(k: String) -> float:
	return rill_len[k] + (_climb[k] as Array).size() * P


## Abscisse curviligne du front d'extinction (px natifs depuis l'arène) ; 0 tant que le gardien vit.
func front(k: String) -> float:
	var a := age(k)
	return 0.0 if a < 0.0 else clampf(a / DRAIN, 0.0, 1.0) * flow_len(k)


## Battement du flot à l'abscisse s (px natifs) : 1 sur un battement, 0 ailleurs.
static func beat(s: float, t: float) -> bool:
	return fposmod(s - t * FLOW_V, FLOW_GAP) < 1.0


# ---------------------------------------------------------------- Dessin

func _draw() -> void:
	var t := GameState.sim_time
	var op := open_age()
	var lit := 0.0 if op < 0.0 else clampf(op / 2.0, 0.0, 1.0)
	_draw_interior(t, lit)
	draw_texture_rect(_base, Rect2(-HALF * P, -106 * P, 192 * P, 108 * P), false)
	_draw_herse(op)
	for k: String in ["a", "m"]:
		_draw_guard(t, k)
	# Losange de la clef de voûte : moitié or, moitié améthyste ; dernier éclat à l'ouverture.
	var kf := 1.0 if op < 0.0 else clampf(1.0 - op / 1.2, 0.0, 1.0)
	var flash := 0.0 if op < 0.0 or op >= 0.4 else 1.0 - op / 0.4
	for j in 7:
		var w := 3 - absi(j - 3)
		for i in range(3 - w, 4 + w):
			var k := "a" if i < 3 else ("m" if i > 3 else "")
			var c: Color
			if flash > 0.0:
				c = _rp(WHITE, 0.5 + flash * 0.5)
			elif k == "":
				c = STONE[6]
			elif age(k) >= OUT_AT + ARCH_DRAIN:
				c = STONE[1]
			else:
				c = _rp(GOLD if k == "a" else AME, (0.6 + 0.25 * sin(t * 2.4)) * kf + 0.1)
			_px(i - 3, -94 + j, c)


func _draw_interior(t: float, lit: float) -> void:
	# Fond de l'embrasure : sombre, la crypte rouge respire derrière la herse ; il s'efface quand la herse est levée
	# (la porte ouverte laisse voir le couloir du jeu).
	var fade := 1.0 - clampf((lit - 0.5) / 0.5, 0.0, 1.0)
	if fade <= 0.0:
		return
	var a := ceilf(fade * 4.0) / 4.0
	var poly := PackedVector2Array()
	for i in 25:
		var u := PI * float(i) / 24.0
		poly.append(Vector2(-cos(u) * AP_RX, SPRING - sin(u) * AP_RY) * P)
	poly.append(Vector2(AP_RX, 0) * P)
	poly.append(Vector2(-AP_RX, 0) * P)
	draw_colored_polygon(poly, Color(DARK[0], a))
	var pulse := 0.85 + 0.15 * sin(t * 2.2)
	var k := (0.22 + 0.78 * lit) * pulse
	for step in range(1, 6):
		var idx := roundi(float(step) / 6.0 * k * 7.0)
		if idx <= 0:
			continue
		var rr := 40.0 * (1.0 - float(step) / 6.0) + 6.0
		var e := PackedVector2Array()
		for i in 24:
			var u := TAU * float(i) / 24.0
			var p := Vector2(cos(u) * rr * 1.25, -6.0 + sin(u) * rr)
			p.x = clampf(p.x, -AP_RX, AP_RX)
			p.y = clampf(p.y, _ap_top(p.x), 0.0)
			e.append(p * P)
		draw_colored_polygon(e, Color(CRIM[idx], a))


func _ap_top(x: float) -> float:
	var u := clampf(x / AP_RX, -1.0, 1.0)
	return SPRING - AP_RY * sqrt(1.0 - u * u)


func _draw_herse(op: float) -> void:
	var off := 0
	if op > HERSE_DELAY:
		off = -2 * mini(NOTCHES, floori((op - HERSE_DELAY) / NOTCH))
	var jolt := 1 if op > HERSE_DELAY and off > -2 * NOTCHES and fposmod(op - HERSE_DELAY, NOTCH) < 0.02 else 0
	# Barreaux : 2 points de large tous les 6 points, pointe en bas.
	for b in 20:
		var x := -58 + b * 6
		var top := maxf(float(-80 + off + jolt), ceilf(_ap_top(x + 1.0)))
		var bottom := float(-2 + off + jolt)
		if bottom <= top:
			continue
		draw_rect(Rect2(x * P, top * P, P, (bottom - top) * P), IRON[5])
		draw_rect(Rect2((x + 1) * P, top * P, P, (bottom - top) * P), IRON[3])
		if bottom + 2.0 > top:
			_px(x, bottom, IRON[4])
			_px(x, bottom + 1, IRON[2])
	# Traverses.
	for yc in [-66, -44, -22]:
		var y := float(yc + off + jolt)
		if y >= 0.0:
			continue
		var hw := AP_RX
		if y < SPRING:
			var v := (y - SPRING) / AP_RY
			if v <= -1.0:
				continue
			hw = AP_RX * sqrt(1.0 - v * v)
		draw_rect(Rect2(-hw * P, y * P, hw * 2.0 * P, P), IRON[5])
		draw_rect(Rect2(-hw * P, (y + 1.0) * P, hw * 2.0 * P, P), IRON[3])
	# Poussière qui tombe pendant la montée.
	if op > HERSE_DELAY and op < 3.4:
		for i in 14:
			var a := op - HERSE_DELAY - _hs(i, 1, 31) * 1.6
			if a > 0.0 and a < 0.9:
				_px(-AP_RX + 4.0 + _hs(i, 2, 31) * (AP_RX * 2.0 - 8.0), -76.0 + a * a * 120.0, ASH[3])


func _flame_of(a: float) -> Vector2:
	# (hauteur, vie)
	if a < DRAIN:
		return Vector2(1.0, 1.0)
	var b := a - DRAIN
	if b < FLARE:
		return Vector2(1.0 + b / FLARE * 0.6, 1.0)
	if b < FLARE + GUTTER:
		var f := 1.0 - (b - FLARE) / GUTTER
		return Vector2(f, f)
	return Vector2.ZERO


func _draw_guard(t: float, k: String) -> void:
	var R: Array = GOLD if k == "a" else AME
	var cx := -NICHE_C if k == "a" else NICHE_C
	var a := age(k)
	var seed := 3 if k == "a" else 7
	# Montée de la rigole : sous la niche (2 points + lèvre), puis incrustation de la robe.
	var climb: Array = _climb[k]
	var fr := front(k)
	for i in climb.size():
		var s: float = rill_len[k] + i * P
		if s < fr:
			continue
		var p: Vector2i = climb[i]
		var b := beat(s, t) and (a < 0.0 or s > fr + 1.0)
		if p.y > SILL:
			_px(p.x, p.y, _rp(R, 0.95 if b else 0.58))
			_px(p.x + 1, p.y, _rp(R, 0.7 if b else 0.38))
		else:
			_px(p.x, p.y, _rp(R, 0.9 if b else 0.5))
	# Flamme.
	var f := _flame_of(a if a >= 0.0 else -1.0)
	if f.y > 0.0:
		var flick := 0.85 + 0.15 * _vn(t * 6.0, 0.0, seed)
		var pump := _arrival(k, t) if a < 0.0 else 0.0
		_flame(cx, BOWL, maxf(2.0, 13.0 * f.x * flick * (1.0 + 0.15 * pump)), 3.6, R, t, seed)
	if a >= OUT_AT - 0.1:
		_motes(cx, BOWL - 2.0, a - OUT_AT + 0.1, seed * 5, 12, 2.4, 3.0, 9.0)
	# Rigole de l'arc, nourrie par la flamme ; elle se vide après l'extinction.
	var arch: Array = _arch[k]
	var drain := 0.0 if a < OUT_AT else clampf((a - OUT_AT) / ARCH_DRAIN, 0.0, 1.0)
	var n0 := floori(drain * arch.size())
	var run := fposmod(t * 34.0, float(arch.size() + 8))
	for i in range(n0, arch.size()):
		var p: Vector2i = arch[i]
		_px(p.x, p.y, _rp(R, 0.55 + (0.4 if absf(i - run) < 2.0 else 0.0)))


func _arrival(k: String, t: float) -> float:
	return exp(-fposmod(t * FLOW_V - flow_len(k), FLOW_GAP) / 2.0)


func _flame(cx: float, by: float, h: float, w: float, R: Array, t: float, seed: int) -> void:
	for y in range(floori(by - h), floori(by)):
		var rel := clampf((by - y) / h, 0.0, 1.0)
		var hw := w * pow(1.0 - rel, 0.7) * (0.7 + 0.3 * sin(rel * 3.1))
		var xo := sin(t * 9.0 + rel * 5.0 + seed) * rel * 1.6
		for x in range(floori(cx - w - 2.0), floori(cx + w + 2.0) + 1):
			var dd := absf(x + 0.5 - cx - xo) / maxf(0.4, hw)
			if dd > 1.0:
				continue
			var heat := (1.0 - dd) * (1.0 - rel * 0.6) + (_vn(x / 2.0, y / 2.0 + t * 6.0, seed) - 0.5) * 0.3
			if heat < 0.08:
				continue
			_px(x, y, _rp(R, clampf(0.35 + heat * 0.9, 0.0, 1.0)))


func _motes(ox: float, oy: float, a0: float, seed: int, n: int, life: float, spread: float, rise: float) -> void:
	for i in n:
		var a := a0 - _hs(i, 1, seed) * 0.5
		if a < 0.0 or a > life:
			continue
		var l := a / life
		_px(ox + (_hs(i, 2, seed) - 0.5) * spread + sin(a * 3.0 + i) * 2.0 * l, oy - a * rise * (0.6 + _hs(i, 3, seed) * 0.6), _rp(ASH, 0.75 - l * 0.6))


## Lueurs en paliers, additives : flammes, clef de voûte, éclat d'ouverture, fond rouge de la porte ouverte.
func _draw_glow() -> void:
	var t := GameState.sim_time
	var op := open_age()
	for k: String in ["a", "m"]:
		var f := _flame_of(age(k) if age(k) >= 0.0 else -1.0)
		var cx := -NICHE_C if k == "a" else NICHE_C
		if f.y > 0.0:
			var flick := 0.85 + 0.15 * _vn(t * 6.0, 0.0, 3 if k == "a" else 7)
			_halo(Vector2(cx, BOWL - 7), 26.0 * flick * (0.4 + 0.6 * f.y), LIGHT[k], 0.4 * f.y)
		var kf := 1.0 if op < 0.0 else clampf(1.0 - op / 1.2, 0.0, 1.0)
		if age(k) < OUT_AT + ARCH_DRAIN:
			_halo(Vector2(-1 if k == "a" else 2, -91), 10.0, LIGHT[k], 0.25 * kf)
	if op >= 0.0 and op < 0.4:
		_halo(Vector2(0, -91), 26.0, Color.WHITE, 0.5 * (1.0 - op / 0.4))


func _halo(c: Vector2, r: float, col: Color, a: float, sy := 1.0) -> void:
	if a <= 0.0:
		return
	var inc := [0.0625, 0.1875, 0.3125, 0.4375]
	_glow.draw_set_transform(c * P, 0.0, Vector2(1.0, sy))
	for i in 4:
		_glow.draw_circle(Vector2.ZERO, r * (1.0 - i * 0.25) * P, Color(col.r * a * inc[i], col.g * a * inc[i], col.b * a * inc[i], 1.0))
	_glow.draw_set_transform(Vector2.ZERO)


func _lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := GameState.sim_time
	for k: String in ["a", "m"]:
		var f := _flame_of(age(k) if age(k) >= 0.0 else -1.0)
		if f.y <= 0.0:
			continue
		out.append({"x": at.x + float(OrbitGate.NICHE_X[k]), "z": at.y + 0.4, "r": 9.0 * f.y * Lighting.flick(t, at.x + k.length(), 0.07),
			"rgb": LIGHT[k], "glow": 0.16 * f.y})
	return out


func _px(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x) * P, floorf(y) * P, P, P), c)


static func _rp(R: Array, v: float) -> Color:
	return R[clampi(roundi(v * (R.size() - 1)), 0, R.size() - 1)]


static func _hs(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 982451653) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffffffff) / 4294967296.0


static func _vn(x: float, y: float, s: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	var u := fx * fx * (3.0 - 2.0 * fx)
	var v := fy * fy * (3.0 - 2.0 * fy)
	var a := _hs(xi, yi, s)
	var b := _hs(xi + 1, yi, s)
	var c := _hs(xi, yi + 1, s)
	var d := _hs(xi + 1, yi + 1, s)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


# ---------------------------------------------------------------- Tracés et façade fixe

## Rigole de l'arc : du haut de la niche à la clef de voûte.
func _arch_path(k: String) -> Array:
	var sgn := -1 if k == "a" else 1
	var out: Array = []
	var add := func(x: float, y: float) -> void:
		var p := Vector2i(roundi(x), roundi(y))
		if out.is_empty() or out[out.size() - 1] != p:
			out.append(p)
	for y in range(SILL - 50, -85, -1):
		add.call(sgn * NICHE_C, y)
	var v := (-84.0 - SPRING) / GROOVE_RY
	var xs := GROOVE_RX * sqrt(maxf(0.0, 1.0 - v * v))
	var x := float(NICHE_C)
	while x >= xs:
		add.call(sgn * x, -84)
		x -= 1.0
	var a := asin(clampf(-v, -1.0, 1.0))
	while a <= PI / 2.0 - 0.09:
		add.call(sgn * GROOVE_RX * cos(a) - (0 if k == "a" else 1), SPRING - GROOVE_RY * sin(a))
		a += 0.01
	return out


## Montée de la rigole d'arrivée : du pied de la face au rebord de la niche, puis la robe jusqu'à la coupe.
func _climb_path(k: String) -> Array:
	var x := -NICHE_C if k == "a" else NICHE_C
	var out: Array = []
	for y in range(-1, BOWL + 3, -1):
		out.append(Vector2i(x, y))
	return out


func _statue(cx: int, x: int, y: int) -> float:
	# Valeur de pierre du moine agenouillé, −1 hors silhouette (repère : rebord de la niche en SILL).
	var dx := x + 0.5 - cx
	var ry := y - SILL + 28
	if ry >= 0 and ry < 11:
		if Vector2(dx, (ry + 0.5 - 6.0) * 1.1).length() >= 5.0:
			return -1.0
		if Vector2(dx, ry + 0.5 - 8.0).length() < 2.6:
			return 0.12
		return 0.5 - ry * 0.01 + (0.1 if dx < -1.0 else -0.05)
	if ry >= 11 and ry < 28:
		var hw := 5.0 + (ry - 11) * 0.25
		if absf(dx) >= hw:
			return -1.0
		return 0.42 + (0.08 if dx < 0.0 else -0.06) + (-0.07 if posmod(x, 4) == 0 else 0.0)
	return -1.0


func _in_ap(x: int, y: int) -> bool:
	if y >= 0 or absf(x + 0.5) >= AP_RX:
		return false
	return y + 0.5 >= _ap_top(x + 0.5)


func _make_base() -> ImageTexture:
	var img := Image.create(192, 108, false, Image.FORMAT_RGBA8)
	var oy := 106
	var put := func(x: int, y: int, c: Color) -> void:
		if x >= -HALF and x < HALF and y >= -oy and y < 2:
			img.set_pixel(x + HALF, y + oy, c)
	for y in range(FACE_TOP, 0):
		for x in range(-HALF, HALF):
			if _in_ap(x, y):
				continue
			var px := x + 0.5
			var py := y + 0.5
			var c: Color
			# Pierre de taille de l'arc (claveaux), jambages, sinon appareil de la face.
			var e_in := Vector2(px / AP_RX, (py - SPRING) / AP_RY).length()
			var e_out := Vector2(px / RING_RX, (py - SPRING) / RING_RY).length()
			if py < SPRING and e_out <= 1.0:
				var ang := atan2(SPRING - py, px)
				var seg := ang / (PI / 11.0)
				var fr := fmod(seg, 1.0)
				if fr < 0.07 or fr > 0.95 or e_out > 0.96:
					c = STONE[1]
				else:
					c = _rp(STONE, 0.5 + (_hs(floori(seg), 0, 7) - 0.5) * 0.12 + (0.2 if e_in < 1.04 else 0.0) + sin(ang) * 0.06 + (_vn(x / 3.0, y / 3.0, 9) - 0.5) * 0.12)
			elif py >= SPRING and absf(px) >= AP_RX and absf(px) < RING_RX:
				var ry := posmod(y - int(SPRING), 9)
				var d := absf(px) - AP_RX
				if ry == 8 or d > 11.5:
					c = STONE[1]
				else:
					c = _rp(STONE, 0.46 + (_hs(floori((y - SPRING) / 9.0), 0 if x < 0 else 1, 8) - 0.5) * 0.12 + (0.2 if d < 1.0 else 0.0) + (0.08 if ry == 0 else 0.0) + (_vn(x / 3.0, y / 3.0, 9) - 0.5) * 0.12)
			else:
				var row := floori((y - FACE_TOP) / 9.0)
				var off := 8 if row % 2 else 0
				var lx := posmod(x + off, 16)
				var ly := posmod(y - FACE_TOP, 9)
				if ly == 8 or lx == 15:
					c = FACE[0]
				else:
					c = _rp(FACE, 0.42 + (_hs(floori((x + off) / 16.0), row, 2) - 0.5) * 0.16 + (0.12 if ly == 0 else 0.0) + float(y - FACE_TOP) / 98.0 * -0.1 + (_vn(x / 5.0, y / 5.0, 3) - 0.5) * 0.14)
				if y < FACE_TOP + 2:
					c = FACE[6] if y == FACE_TOP else FACE[4]
			put.call(x, y, c)
	# Clef de voûte, qui dépasse du haut de la face.
	for y in range(-104, -84):
		for x in range(-7, 7):
			var w := 7.0 - (y + 104) * 0.08
			if absf(x + 0.5) > w:
				continue
			var edge := absf(x + 0.5) > w - 1.0 or y == -104 or y == -85
			put.call(x, y, STONE[1] if edge else _rp(STONE, 0.58 + (0.12 if y == -103 else 0.0) + (_vn(x / 3.0, y / 3.0, 10) - 0.5) * 0.12))
	# Niches, moines, coupes, rigoles gravées.
	for k: String in ["a", "m"]:
		var cx := -NICHE_C if k == "a" else NICHE_C
		for y in range(SILL - 48, SILL):
			for x in range(cx - 9, cx + 10):
				var dx := x + 0.5 - cx
				var top := Vector2(dx, y + 0.5 - (SILL - 40)).length() if y + 0.5 < SILL - 40 else absf(dx)
				if top > 9.0:
					continue
				var c: Color = STONE[1] if top > 8.0 else (_rp(STONE, 0.45) if top > 7.0 else _rp(DARK, 0.12 + float(y - SILL + 48) / 48.0 * 0.5 + (_vn(x / 3.0, y / 3.0, 12) - 0.5) * 0.2))
				put.call(x, y, c)
		for x in range(cx - 9, cx + 10):
			put.call(x, SILL, STONE[5])
			put.call(x, SILL + 1, STONE[3])
		for y in range(SILL - 28, SILL):
			for x in range(cx - 9, cx + 10):
				var v := _statue(cx, x, y)
				if v >= 0.0:
					put.call(x, y, _rp(STONE, v + (_vn(x / 2.0, y / 2.0, 13) - 0.5) * 0.1))
		for x in range(cx - 4, cx + 5):
			put.call(x, BOWL, STONE[6])
			put.call(x, BOWL + 1, STONE[4])
			put.call(x, BOWL + 2, STONE[3])
		for x in range(cx - 2, cx + 3):
			put.call(x, BOWL + 3, STONE[2])
		for p: Vector2i in _arch[k]:
			put.call(p.x, p.y, STONE[0])
		for p: Vector2i in _climb[k]:
			if p.y > SILL:
				put.call(p.x - 1, p.y, FACE[3])
				put.call(p.x, p.y, DARK[0])
				put.call(p.x + 1, p.y, DARK[0])
				put.call(p.x + 2, p.y, DARK[1])
			elif p.y < SILL:
				put.call(p.x, p.y, STONE[1])
	return ImageTexture.create_from_image(img)
