class_name OeilRoots
extends RefCounted
## Ancrage de l'Œil de la Matrice dans le sol de sa salle (dessiné par OeilFx, sous les sprites) :
## - une nappe de chair sombre aux bords tramés, étalée sur les dalles autour de la base, d'où rayonnent des veines qui
##   continuent en fissures au-delà de la nappe (texture calculée une fois) ;
## - le pouls : un trait clair qui court le long de chaque veine, de la base vers le bord, plus vite à chaque phase ;
## - des tentacules de la couleur du corps qui sortent de sous la masse et rampent sur les dalles : ils ondulent au
##   repos, s'agitent quand l'œil s'ouvre, et fouettent en l'air quand il est touché ou que les racines frappent ;
## - (par-dessus les sprites) des spores qui montent autour de la masse.
## Tout s'efface avec le corps à sa mort. Repère : pixels natifs du monde.

const OUT := Color("#0b090b")
const FLESH: Array[Color] = [Color("#2c2024"), Color("#4c3a3c"), Color("#76605e"), Color("#a08a82"), Color("#c8b4a8")]
const GORE: Array[Color] = [Color("#2a0a0c"), Color("#4a0a0e"), Color("#7e1216"), Color("#e2382e"), Color("#ff8a6a")]
const SHADOW := Color(0.03, 0.01, 0.01, 0.45)
## Demi-axes de la nappe (px) et décalage de son centre sous l'ancre du corps.
const RX := 132
const RY := 54
const DOWN := 5.0
## Demi-axes du pourtour d'où sortent les tentacules (px).
const BASE := Vector2(76.0, 15.0)
## Angle à l'écran (0 = est, 90° = vers le bas), longueur (px), phase.
const TENTACLES := [[-14.0, 50.0, 0.0], [14.0, 62.0, 1.7], [40.0, 44.0, 3.1], [66.0, 26.0, 4.6], [116.0, 28.0, 0.9],
	[140.0, 46.0, 2.4], [166.0, 64.0, 5.3], [194.0, 48.0, 3.8]]
const BEAT := [0.55, 0.8, 1.15]
const LASH := 0.45
static var _creep: Texture2D
static var _veins: Array[PackedVector2Array] = []


static func _hash(i: float) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)


static func _build() -> void:
	var img := Image.create(2 * RX + 1, 2 * RY + 1, false, Image.FORMAT_RGBA8)
	for y in range(-RY, RY + 1):
		for x in range(-RX, RX + 1):
			var a := atan2(float(y) / RY, float(x) / RX)
			var e := 0.76 + 0.12 * sin(a * 5.0 + 1.3) + 0.08 * sin(a * 11.0 + 4.1) + 0.04 * sin(a * 23.0 + 2.2)
			var v := Vector2(float(x) / RX, float(y) / RY).length() / e
			if v >= 1.0:
				continue
			var bay := OeilFx._bay(x, y)
			if 1.0 - smoothstep(0.5, 1.0, v) <= bay:
				continue
			var c := GORE[0] if v > 0.72 else FLESH[0] if v + bay * 0.3 > 0.5 else FLESH[1] if (x + y) & 1 else FLESH[0]
			img.set_pixel(x + RX, y + RY, Color(c, 0.92))
	# Veines : marche du pourtour vers l'extérieur, qui zigzague ; au-delà de la nappe, elles deviennent des fissures.
	_veins.clear()
	for i in 18:
		var a := i * TAU / 18.0 + (_hash(i) - 0.5) * 0.25
		var p := Vector2(cos(a) * RX, sin(a) * RY) * 0.4
		var pts := PackedVector2Array()
		var steps := 22 + int(_hash(i + 40.0) * 12.0)
		for k in steps:
			pts.append(p.round())
			var dir := Vector2(cos(a), sin(a) * 0.45).normalized()
			a += (_hash(i * 31.0 + k) - 0.5) * 0.5
			p += dir * 3.0
			if absf(p.x) > RX - 2 or absf(p.y) > RY - 2:
				break
		_veins.append(pts)
		for k in pts.size():
			var q := pts[k]
			var far := float(k) / pts.size() > 0.62
			var col := Color(OUT, 0.7) if far else GORE[2] if k % 5 else GORE[1]
			# Trait continu entre deux points de la marche.
			var nx: Vector2 = pts[mini(k + 1, pts.size() - 1)]
			for t in 4:
				var w := q.lerp(nx, t / 4.0).round()
				img.set_pixel(int(w.x) + RX, int(w.y) + RY, col)
				if not far and k < 6:
					img.set_pixel(int(w.x) + RX, clampi(int(w.y) + 1 + RY, 0, 2 * RY), GORE[1])
	_creep = ImageTexture.create_from_image(img)


## Sol : nappe, pouls des veines, tentacules. e : le boss ; r : OeilMatrice.run().
static func draw_ground(ci: CanvasItem, e: Enemy, r: Dictionary, now: float) -> void:
	if _creep == null:
		_build()
	var c := Proj.nat(e.x, 0.0, e.z).round() + Vector2(0.0, DOWN)
	var dead := e.hp <= 0.0
	var al := 1.0
	if dead:
		al = 1.0 - clampf((now - e.died_at) / OeilMatrice.COLLAPSE, 0.0, 1.0)
	var ph := clampi(int(r.get("phase", 0)), 0, 2)
	var open: float = r.get("open", 0.0)
	ci.draw_texture(_creep, c - Vector2(RX, RY), Color(1, 1, 1, al))
	if not dead:
		var beat: float = BEAT[ph]
		for i in _veins.size():
			var pts := _veins[i]
			var head := int(fposmod(now * beat - i * 0.137, 1.0) * (pts.size() + 10))
			for k in range(head - 3, head + 1):
				if k >= 0 and k < pts.size():
					ci.draw_rect(Rect2(c + pts[k], Vector2.ONE), GORE[4] if k == head else GORE[3])
	# Tentacules : fouet quand il est touché ou que les racines frappent.
	var lash := 0.0
	if not dead:
		var since := minf(now - e.hurt_at, now - (float(r.get("root_at", -INF)) - OeilMatrice.ROOT_EVERY))
		if since >= 0.0 and since < LASH:
			lash = sin(since / LASH * PI)
	var agit := 0.0 if dead else 0.55 + 0.45 * open + 0.2 * ph
	for t: Array in TENTACLES:
		_tentacle(ci, c - Vector2(0.0, DOWN - 2.0), deg_to_rad(t[0]), t[1], t[2], now, agit, lash, ph, al)


static func _tentacle(ci: CanvasItem, c: Vector2, a: float, length: float, phase: float, now: float, agit: float, lash: float,
		ph: int, al: float) -> void:
	var root := c + Vector2(cos(a) * BASE.x, sin(a) * BASE.y)
	var dir := Vector2(cos(a), sin(a) * 0.5).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var n := ceili(length / 1.5)
	var w := 2.0 + 0.7 * ph
	var pts: Array[Vector3] = []
	for i in n + 1:
		var s := float(i) / n
		var wave := sin(s * 5.5 - now * w + phase) * 7.0 * agit * pow(s, 1.4)
		var up := (3.0 * agit * (0.5 + 0.5 * sin(now * 1.3 + phase * 2.0)) + 16.0 * lash) * s * s
		var g := root + dir * length * s * (1.0 - 0.12 * lash) + perp * wave * Vector2(1.0, 0.5)
		var rad := lerpf(4.6, 0.8, sqrt(s))
		pts.append(Vector3(g.x, g.y - up, rad))
		if up > 2.0 and i % 2 == 0:
			ci.draw_rect(Rect2(Vector2(g.x - rad, g.y + 1.0).round(), Vector2(2.0 * rad + 1.0, 1.0)), Color(SHADOW, SHADOW.a * al))
	for p in pts:
		_disc(ci, p.x, p.y, p.z + 1.0, Color(OUT, al))
	for i in pts.size():
		var p := pts[i]
		# Anneaux plus sombres, comme les plis du corps.
		_disc(ci, p.x, p.y, p.z, Color(FLESH[1] if i % 7 == 6 else FLESH[2], al))
	for p in pts:
		if p.z >= 1.6:
			_disc(ci, p.x, p.y - p.z * 0.45, p.z * 0.45, Color(FLESH[3], al))
	var tip := pts[pts.size() - 1]
	ci.draw_rect(Rect2(Vector2(tip.x, tip.y).round(), Vector2.ONE), Color(GORE[3], al))


static func _disc(ci: CanvasItem, cx: float, cy: float, r: float, col: Color) -> void:
	var x0 := roundf(cx)
	var y0 := roundf(cy)
	for y in range(-floori(r), floori(r) + 1):
		var h := floorf(sqrt(r * r - y * y))
		ci.draw_rect(Rect2(x0 - h, y0 + y, 2.0 * h + 1.0, 1.0), col)


## Par-dessus les sprites : spores qui montent autour de la masse, plus nombreuses à chaque phase.
static func draw_air(ci: CanvasItem, e: Enemy, r: Dictionary, now: float) -> void:
	if e.hp <= 0.0:
		return
	var c := Proj.nat(e.x, 0.0, e.z).round()
	var ph := clampi(int(r.get("phase", 0)), 0, 2)
	for i in 10 + 6 * ph:
		var k := fposmod(now * (0.16 + 0.08 * _hash(i)) + _hash(i + 9.0), 1.0)
		var x := (_hash(i + 3.0) - 0.5) * 2.0 * (RX - 20) + sin(now * 0.9 + i) * 4.0
		var y := (_hash(i + 5.0) - 0.5) * 30.0 - k * 70.0
		var al := sin(k * PI) * 0.8
		ci.draw_rect(Rect2((c + Vector2(x, y)).round(), Vector2.ONE), Color(GORE[4] if i % 3 == 0 else FLESH[4], al))
