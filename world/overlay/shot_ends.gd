class_name ShotEnds
extends RefCounted
## Fin de vie des projectiles (planche « Fin des projectiles », bilan du 2026-11-23) : écrasement contre un mur
## (« wall ») et extinction en fin de portée (« range ») pour les six tirs ennemis, l'éclat d'or de la Martyre et les
## cinq balles de l'Arbalestrie. Dessin seul, en pixels natifs tramés ; rien ne touche pendant ces animations.
## Les dessins sont écrits pour un vol vers la droite puis portés dans le repère du tir : avant d, travers n (côté
## haut de l'écran). La pesanteur, les coulures et la fumée restent verticales à l'écran.

## Durées (s) : [mur, portée]. Lues par la simulation (EnemyShots, Combat, Martyre, OeilMatrice).
const DUR := {
	"arrow": [0.55, 0.4], "orb": [0.42, 0.48], "fire": [0.55, 0.5], "ichor": [0.55, 0.5], "bone": [0.38, 0.36],
	"shard": [0.24, 0.2], "or": [0.42, 0.5],
	"spirit": [0.32, 0.28], "indra": [0.45, 0.42], "medeina": [0.55, 0.6], "sigil": [0.42, 0.36], "aether": [0.42, 0.42],
}
## Recul du centre de la balle par rapport à la face du mur (px natifs).
const NOSE := {"arrow": 3.0, "orb": 5.0, "fire": 6.0, "ichor": 3.0, "bone": 3.0, "shard": 2.0, "or": 6.0,
	"spirit": 2.0, "indra": 3.0, "medeina": 2.0, "sigil": 2.0, "aether": 2.0}

const INK := Color("#0a0a0c")
const SHADOW := Color(0.0, 0.0, 0.0, 0.4)
const SMOKE: Array[Color] = [Color("#c9cdd6"), Color("#9aa1b0"), Color("#6d7482")]
const DUST: Array[Color] = [Color("#8a8e98"), Color("#565c6c")]
const WOOD_DARK := Color("#3e2a18")
const LIGHT: Array[Color] = [Color("#3a280c"), Color("#6a4a16"), Color("#a07424"), Color("#d0a038"), Color("#f0cc66"), Color("#fff2b0"), Color("#fffbe8")]
const DIAG_BACK: Array[Vector2] = [Vector2(-2, -2), Vector2(-2, 2)]

static var _ci: CanvasItem
static var _px := 1.0
static var _ga := 1.0
static var _o := Vector2.ZERO
static var _d := Vector2.RIGHT
static var _n := Vector2.UP
static var _gy := 0.0
static var _w := 0.0


## Dessine la fin `mode` du projectile `kind` âgée de `age` s. at : centre de la balle à sa fin, ground_y : sol sous
## elle, dir : sens du vol à l'écran, px : pixels d'écran par pixel natif. back : la balle est déjà dans la roche,
## on la recule de son nez. scale : taille de la braise (alpha des meutes, balles de l'Œil).
static func draw(ci: CanvasItem, px: float, kind: String, mode: String, at: Vector2, ground_y: float, dir: Vector2,
		age: float, back := true, scale := 1.0) -> void:
	if not DUR.has(kind) or age < 0.0:
		return
	var wall := mode == "wall"
	var dur: float = DUR[kind][0 if wall else 1]
	if age >= dur:
		return
	_ci = ci
	_px = px
	_ga = 1.0
	_d = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	_n = Vector2(-_d.y, _d.x)
	if _n.y > 0.0:
		_n = -_n
	_w = NOSE[kind]
	_o = at - _d * _w if wall and back else at
	_gy = ground_y
	var p := age / dur
	match kind:
		"arrow":
			if wall: _arrow_wall(age, p)
			else: _arrow_range(p)
		"orb":
			if wall: _orb_wall(age, p)
			else: _orb_range(age, p)
		"fire":
			if wall: _fire_wall(age, p, scale)
			else: _fire_range(age, p, scale)
		"ichor":
			if wall: _ichor_wall(age, p)
			else: _ichor_range(age, p)
		"bone":
			if wall: _bone_wall(age, p)
			else: _bone_range(p)
		"shard":
			if wall: _iron_wall(age, p)
			else: _iron_range(p)
		"or":
			if wall: _or_wall(age, p)
			else: _or_range(p)
		"spirit":
			if wall: _spirit_wall(age, p)
			else: _spirit_range(age, p)
		"indra":
			if wall: _indra_wall(age, p)
			else: _indra_range(age, p)
		"medeina":
			if wall: _medeina_wall(age, p)
			else: _medeina_range(age, p)
		"sigil":
			if wall: _sigil_wall(age, p)
			else: _sigil_range(age, p)
		"aether":
			if wall: _aether_wall(age, p)
			else: _aether_range(age, p)
	_ga = 1.0


# ---------------------------------------------------------------- Outils

static func _bay(x: int, y: int) -> float:
	return EffectsDrawer.BAYER[y & 3][x & 3]


## Pixel natif, tramé par l'opacité générale _ga.
static func P(v: Vector2, c: Color) -> void:
	var x := floori(v.x + 0.5)
	var y := floori(v.y + 0.5)
	if _ga < 1.0 and _bay(x, y) >= _ga:
		return
	_ci.draw_rect(Rect2(x * _px, y * _px, _px, _px), c)


## Pixel natif tramé selon a.
static func D(v: Vector2, c: Color, a: float) -> void:
	var x := floori(v.x + 0.5)
	var y := floori(v.y + 0.5)
	if _bay(x, y) < a * _ga:
		_ci.draw_rect(Rect2(x * _px, y * _px, _px, _px), c)


## Point du repère du tir : fx vers l'avant, fy vers le bas quand le tir va à droite.
static func L(fx: float, fy: float) -> Vector2:
	return _o + _d * fx - _n * fy


static func _fade(p: float, k := 1.0) -> float:
	return clampf((1.0 - p) * k, 0.0, 1.0)


static func _h(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


## Particule lancée du point (fx, fy) du repère à la vitesse (vx, vy) du repère, pesanteur g à l'écran.
static func _shot(fx: float, fy: float, vx: float, vy: float, g: float, a: float, ground := true) -> Vector2:
	var s := L(fx, fy) + (_d * vx - _n * vy) * a + Vector2(0.0, 0.5 * g * a * a)
	if ground and s.y > _gy:
		s.y = _gy
	return s


## Point du sol sous le point (fx, 0) du repère.
static func _ground(fx: float) -> Vector2:
	return Vector2(L(fx, 0.0).x, _gy)


## Disque droit à l'écran ; a < 0 : plein.
static func _disc(c: Vector2, r: float, col: Color, a := -1.0) -> void:
	_sell(c, r, r, col, a)


## Ellipse droite à l'écran.
static func _sell(c: Vector2, rx: float, ry: float, col: Color, a := -1.0) -> void:
	if rx < 0.4 or ry < 0.4:
		return
	var x0 := floorf(c.x + 0.5)
	var y0 := floorf(c.y + 0.5)
	var m := floori(ry)
	for y in range(-m, m + 1):
		var h := floori(rx * sqrt(maxf(0.0, 1.0 - y * y / (ry * ry))))
		for x in range(-h, h + 1):
			if a < 0.0:
				P(Vector2(x0 + x, y0 + y), col)
			else:
				D(Vector2(x0 + x, y0 + y), col, a)


## Ellipse du repère du tir (rx le long du vol, ry le long du mur), centrée en (fx, fy). loz : losange.
static func _oell(fx: float, fy: float, rx: float, ry: float, col: Color, a := -1.0, loz := false, core := 0.0) -> void:
	if rx < 0.4 or ry < 0.4:
		return
	var c := L(fx, fy)
	var m := ceili(maxf(rx, ry))
	var x0 := floorf(c.x + 0.5)
	var y0 := floorf(c.y + 0.5)
	for y in range(-m, m + 1):
		for x in range(-m, m + 1):
			var q := Vector2(x, y)
			var u := q.dot(_d) / rx
			var v := q.dot(_n) / ry
			var k := absf(u) + absf(v) if loz else u * u + v * v
			if k > 1.0:
				continue
			var cc := col
			if loz:
				cc = Color.WHITE if k < core else LIGHT[5] if k < 0.75 else LIGHT[4]
			if a < 0.0:
				P(Vector2(x0 + x, y0 + y), cc)
			else:
				D(Vector2(x0 + x, y0 + y), cc, a)


static func _pts(c: Vector2, list: Array[Vector2], col: Color, a := -1.0) -> void:
	for q: Vector2 in list:
		if a < 0.0:
			P(c + q, col)
		else:
			D(c + q, col, a)


## Points donnés dans le repère du tir autour de (fx, fy).
static func _lpts(fx: float, fy: float, list: Array[Vector2], col: Color, a := -1.0) -> void:
	for q: Vector2 in list:
		if a < 0.0:
			P(L(fx + q.x, fy + q.y), col)
		else:
			D(L(fx + q.x, fy + q.y), col, a)


static func _ring(c: Vector2, r: float, col: Color, a: float, count: int) -> void:
	for k in count:
		var t := TAU * k / count
		D(c + Vector2(cos(t), sin(t)) * r, col, a)


static func _cross2(c: Vector2, col: Color) -> void:
	_pts(c, [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)], col)


static func _shadow(g: Vector2, count := 3) -> void:
	for i in count:
		P(g + Vector2(i - 1, 0), SHADOW)


## Poussière soulevée au sol derrière un point.
static func _puff(g: Vector2, e: float) -> void:
	for sx: float in [-1.0, 1.0]:
		D(g + Vector2(sx * (2.0 + e * 3.0), -e * 2.0), DUST[0], 0.7 * (1.0 - e))


# ---------------------------------------------------------------- Projectiles (portés de EffectsDrawer)

## Flèche de EffectsDrawer._arrow_at, limitée aux rangs i0..i1 (0 : pointe, 11 : empennage).
static func _arrow(q: Vector2, u: Vector2, i0: int, i1: int) -> void:
	var s := Vector2(u.y, -u.x)
	for i in range(maxi(i0, -1), mini(i1, 11) + 1):
		P(q - u * i + s, INK)
		P(q - u * i - s * 2.0, INK)
	for i in range(maxi(i0, 0), mini(i1, 10) + 1):
		P(q - u * i, EffectsDrawer.ARROW_HEAD if i < 3 else EffectsDrawer.ARROW_SHAFT)
		P(q - u * i - s, Color("#a2a6ab") if i < 3 else WOOD_DARK)
	if i0 <= -1:
		P(q + u, EffectsDrawer.ARROW_TIP)
		P(q + u * 2.0, Color.WHITE)
	if i0 <= 1 and i1 >= 1:
		for sg: float in [-1.0, 1.0]:
			P(q - u - s * (sg * 1.5), EffectsDrawer.ARROW_HEAD)
	for sg: float in [-1.0, 1.0]:
		for i in range(maxi(i0, 8), mini(i1, 11) + 1):
			P(q - u * i - s * (sg * 2.0), EffectsDrawer.ARROW_FL)


## Éclat d'os de EffectsDrawer._bone_at, limité aux rangs ≤ i1 (-2 : pointe, 6 : chair).
static func _bone(q: Vector2, u: Vector2, i1: int) -> void:
	var B: Array[Color] = EffectsDrawer.BONE_SHARD
	var s := Vector2(-u.y, u.x)
	for i in range(-1, mini(i1, 6) + 1):
		P(q - u * i + s, B[0])
		P(q - u * i - s, B[0])
	P(q + u * 2.0, B[0])
	for i in range(0, mini(i1, 5) + 1):
		P(q - u * i, B[4] if i < 1 else B[3] if i < 3 else B[2] if i < 4 else B[1])
	P(q + u, B[4])


static func _ichor(q: Vector2, u: Vector2) -> void:
	var I: Array[Color] = EffectsDrawer.ICHOR_DROP
	for y in range(-3, 4):
		for x in range(-3, 4):
			var a := (x * u.x + y * u.y) / 1.2
			var b := -x * u.y + y * u.x
			var r := sqrt(a * a + b * b)
			if r > 3.1:
				continue
			var ri := Vector2(x + 0.5, y + 0.5).length()
			P(q + Vector2(x, y), I[0] if r > 2.3 else I[3] if ri < 0.9 else I[2] if ri < 1.7 else I[1])


static func _fire(q: Vector2, t: float, s: float) -> void:
	var F: Array[Color] = EffectsDrawer.FIREBALL
	var R := Rng.new(7)
	for i in range(6, 2, -1):
		D(q - _d * (i * 3.3 * s) + Vector2((R.next() - 0.5) * 4.5 * s, sin(t * 22.0 + i * 1.7) * 2.2), F[0 if i > 4 else 1], 1.15 - i * 0.15)
	for i in range(6, 2, -1):
		_disc(q - _d * (i * 1.5 * s), (3.9 - (i - 3) * 0.9) * s, F[1])
	_disc(q, 6.3 * s, F[6])
	_disc(q, 4.8 * s, F[2])
	_disc(q + _d * 1.5 * s, 3.0 * s, F[3])
	_disc(q + _d * 1.5 * s, 1.5 * s, F[4] if fposmod(t * 16.0 + R.next(), 2.0) < 1.0 else F[5])


static func _rim(c: Vector2, col: Color) -> void:
	_pts(c, EffectsDrawer.RIM12, col)


# ---------------------------------------------------------------- Tirs ennemis

## Fichée : la pointe entre de 3 px dans la roche, le fût vibre, trois éclats de pierre retombent.
static func _arrow_wall(a: float, p: float) -> void:
	var w := sin(a * 70.0) * 0.16 * exp(-a * 11.0)
	_ga = 1.0 if p < 0.55 else _fade((p - 0.55) / 0.45)
	_arrow(L(_w + 2.0, 0.0), (_d * cos(w) - _n * sin(w)).normalized(), 2, 11)
	_ga = 1.0
	if a < 0.05:
		_lpts(_w - 1.0, 0.0, [Vector2(0, -1), Vector2(0, 0), Vector2(0, 1), Vector2(-1, 0)], Color.WHITE)
	var V: Array[Vector2] = [Vector2(-30, -28), Vector2(-18, -44), Vector2(-42, -6)]
	for i in 3:
		D(_shot(_w - 1.0, 0.0, V[i].x, V[i].y, 170.0, a), DUST[1 if i == 1 else 0], _fade(p, 1.4))


## Essoufflée (reprise B) : pas de chute, la flèche ralentit et s'efface de l'empennage vers la pointe.
static func _arrow_range(p: float) -> void:
	var x := roundf(6.0 * (1.0 - (1.0 - p) * (1.0 - p)))
	if p < 0.9:
		_arrow(L(x, 0.0), _d, -1, floori(15.0 * (1.0 - p) - 3.0))
	else:
		D(L(x + 2.0, 0.0), Color.WHITE, _fade((p - 0.9) / 0.1, 2.0))
	_shadow(_ground(x), roundi(3.0 * (1.0 - p)))
	var bits: Array = [[EffectsDrawer.ARROW_FL, 0.0], [EffectsDrawer.ARROW_SHAFT, 0.2], [WOOD_DARK, 0.4]]
	for i in 3:
		var st: float = bits[i][1]
		if p > st:
			var e := (p - st) / (1.0 - st)
			D(L(x - 11.0 + i * 4.0 - e * 4.0, 0.0) + Vector2(0.0, (i - 1) + e * (4.0 + i)), bits[i][0], 0.9 * (1.0 - e))


## Écrasée : galette contre la paroi, sept gouttes à l'opposé, coulure sombre.
static func _orb_wall(a: float, p: float) -> void:
	var O: Array[Color] = EffectsDrawer.ORB
	var x := _w - 3.0
	_oell(_w + 1.0, 0.0, 1.5, 4.0 + p * 2.0, O[0], _fade(p, 1.1))
	if a < 0.07:
		_oell(x, 0.0, 3.5, 8.0, Color.BLACK)
		_oell(x, 0.0, 2.6, 7.0, O[0])
		_oell(x, 0.0, 2.0, 5.6, O[1])
		_oell(x + 1.0, 0.0, 1.0, 3.6, O[2])
		return
	if a < 0.14:
		_disc(L(x, 0.0), 2.2, O[3])
	for i in 7:
		var an := PI / 2.0 + (i + 0.5) / 7.0 * PI
		var sp := 34.0 + _h(i, 2.0) * 22.0
		var s := _shot(x, 0.0, cos(an) * sp, sin(an) * sp, 130.0, a)
		D(s, O[2] if i % 2 else O[1], _fade(p, 1.5))
		D(s + Vector2(0, 1), O[0], _fade(p, 1.2))


## Dissipée : l'orbe ralentit et se vide du bord vers le cœur, trois volutes montent.
static func _orb_range(a: float, p: float) -> void:
	var O: Array[Color] = EffectsDrawer.ORB
	var c := L(5.0 * (1.0 - (1.0 - p) * (1.0 - p)), 0.0)
	var s := 1.0 - p
	if p < 0.86:
		_disc(c, 5.5 * s, Color.BLACK)
		_disc(c, 4.5 * s, O[0])
		_disc(c, 3.5 * s, O[1])
		_disc(c, 2.2 * s, O[2])
		_disc(c - Vector2(0.5, 0.5), maxf(s, 0.6), O[3])
	else:
		D(c, O[3], _fade((p - 0.86) / 0.14))
	for i in 3:
		var st := 0.15 + i * 0.12
		if p > st:
			var e := (p - st) / (1.0 - st)
			D(c + Vector2(-3.0 + i * 3.0 + sin(a * 16.0 + i * 2.0) * 1.2, -2.0 - e * (9.0 + i * 2.0)), O[2] if i == 1 else O[1], 0.9 * (1.0 - e))


## Gerbe et suie : éclair aplati, flamme qui lèche la paroi, neuf escarbilles, tache de suie.
static func _fire_wall(a: float, p: float, s: float) -> void:
	var F: Array[Color] = EffectsDrawer.FIREBALL
	var x := _w - 3.0
	_oell(_w + 1.0, 0.0, 2.4 * s, 5.5 * s, Color("#0a080a"), 0.85 * _fade(p, 1.2))
	if a < 0.06:
		_oell(x, 0.0, 3.6 * s, 8.5 * s, F[6])
		_oell(x, 0.0, 2.8 * s, 7.4 * s, F[2])
		_oell(x + 1.0, 0.0, 1.6 * s, 5.0 * s, F[3])
		_oell(x + 1.0, 0.0, 0.9 * s, 3.4 * s, F[4])
		return
	if a < 0.3:
		var e := a / 0.3
		var m := roundi((5.0 + e * 7.0) * s)
		var f := 1.0 if e < 0.6 else _fade((e - 0.6) / 0.4)
		for j in m + 1:
			var k := float(j) / m
			D(L(_w - 1.0, 3.0 - j), F[5] if k < 0.3 else F[3] if k < 0.6 else F[2], f)
			if k < 0.55:
				D(L(_w - 2.0, 3.0 - j + ((j + int(a * 30.0)) % 2)), F[3] if k < 0.3 else F[1], f)
	for i in 9:
		var an := PI / 2.0 + (i + 0.5) / 9.0 * PI
		var sp := (30.0 + _h(i, 5.0) * 45.0) * s
		var q := _shot(x, 0.0, cos(an) * sp, sin(an) * sp - 12.0, 160.0, a, false)
		if q.y > _gy:
			q.y = _gy - absf(sin(a * 14.0 + i)) * 2.5 * (1.0 - p)
		D(q, F[4] if p < 0.25 else F[3] if p < 0.5 else F[2] if p < 0.75 else F[1], _fade(p * p, 1.3))


## Étouffée : la braise rétrécit en tison, trois bouffées de fumée, une dernière étincelle.
static func _fire_range(a: float, p: float, s: float) -> void:
	var F: Array[Color] = EffectsDrawer.FIREBALL
	var c := L(6.0 * (1.0 - (1.0 - p) * (1.0 - p)), 0.0)
	for i in 3:
		var st := 0.18 + i * 0.14
		if p > st:
			var e := (p - st) / (1.0 - st)
			_disc(c + Vector2(-3.0 + i * 3.0 + sin(a * 9.0 + i) * 1.5, -3.0 - e * (10.0 + i * 2.0)), 1.4 + e * 1.4, SMOKE[2 - i % 2], 0.6 * (1.0 - e))
	if p < 0.3:
		_fire(c, a, s * (1.0 - p * 1.2))
	elif p < 0.62:
		var k := (1.0 - (p - 0.3) * 1.6) * s
		_disc(c, 4.4 * k, F[6])
		_disc(c, 3.0 * k, F[1])
		_disc(c, 1.5 * k, F[3] if p < 0.45 else F[2])
	else:
		_disc(c, 2.0 * s, F[0], _fade((p - 0.62) / 0.38, 1.4))
		if p < 0.8:
			P(c, F[1])
	if p > 0.45 and p < 0.7:
		var e := (p - 0.45) / 0.25
		P(c + Vector2(3.0 + e * 2.0, -4.0 - e * 5.0), Color.WHITE if e < 0.6 else F[3])


## Coulure : tache sur la paroi, deux filets qui coulent, trois gouttelettes en arrière.
static func _ichor_wall(a: float, p: float) -> void:
	var I: Array[Color] = EffectsDrawer.ICHOR_DROP
	var x := _w - 1.0
	var ry := 2.5 + clampf(a / 0.06, 0.0, 1.0) * 2.5
	var f := _fade(p, 1.7)
	_oell(x, 0.0, 2.2, ry + 1.0, I[0], f)
	_oell(x, 0.0, 1.3, ry, I[1], f)
	_oell(x - 1.0, -1.0, 0.6, ry - 2.0, I[2], f)
	D(L(x - 1.0, -2.0), I[3], f)
	var base := L(x, 0.0) + Vector2(0.0, ry)
	var drips: Array[Vector3] = [Vector3(0, 7, 30), Vector3(-1, 5, 22)]
	for dr: Vector3 in drips:
		var m := mini(int(dr.y), int(a * dr.z))
		for j in m + 1:
			D(base + Vector2(dr.x, j), I[2] if j == m else I[1], f)
	var V: Array[Vector2] = [Vector2(-26, -32), Vector2(-38, -8), Vector2(-16, 8)]
	for v: Vector2 in V:
		var s := _shot(x - 2.0, 0.0, v.x, v.y, 160.0, a)
		D(s, I[2], _fade(p, 1.5))
		D(s + Vector2(0, 1), I[0], _fade(p, 1.5))


## Flaque : la goutte tombe en s'étirant et s'étale au sol, deux éclaboussures.
static func _ichor_range(a: float, p: float) -> void:
	var I: Array[Color] = EffectsDrawer.ICHOR_DROP
	var T := 0.14
	if a < T:
		var k := a / T
		_ichor((L(3.0 * k, 0.0) + Vector2(0.0, (_gy - 2.0 - _o.y) * k * k)).round(), Vector2.DOWN)
		_shadow(_ground(3.0 * k))
		return
	var g := _ground(3.0)
	var e := clampf((a - T) / 0.08, 0.0, 1.0)
	var f := _fade(p, 2.2)
	_sell(g, 3.0 + e * 2.0, 1.6, I[0], f)
	_sell(g, 2.0 + e * 2.0, 0.8, I[1], f)
	D(g + Vector2(-1, 0), I[2], f)
	D(g + Vector2(1, 0), I[2], f)
	if e < 1.0:
		P(g + Vector2(0, -1), I[3])
	if a < T + 0.16:
		var j := (a - T) / 0.16
		for sx: float in [-1.0, 1.0]:
			D(g + Vector2(sx * (3.0 + j * 3.0), -1.0 - sin(j * PI) * 4.0), I[2], 1.0 - j * 0.5)


## Brisé : trait blanc sur la paroi, trois morceaux qui tournoient et retombent.
static func _bone_wall(a: float, p: float) -> void:
	var B: Array[Color] = EffectsDrawer.BONE_SHARD
	if a < 0.05:
		_lpts(_w - 1.0, 0.0, [Vector2(0, -2), Vector2(0, -1), Vector2(0, 0), Vector2(0, 1), Vector2(0, 2), Vector2(-1, 0)], Color.WHITE)
	D(L(_w, 0.0), INK, _fade(p, 1.5))
	var V: Array[Vector2] = [Vector2(-40, -36), Vector2(-25, -56), Vector2(-52, -10)]
	var f := _fade(p, 1.6)
	for i in 3:
		var s := _shot(_w - 2.0, 0.0, V[i].x, V[i].y, 230.0, a)
		var an := 0.0 if s.y >= _gy else a * 26.0 + i * 2.0
		D(s, B[4 - i], f)
		D(s + Vector2(roundf(cos(an)), roundf(sin(an))), B[3 - i], f)
		D(s + Vector2(0, 1), B[0], f * 0.8)


## Poussière d'os (reprise B) : pas de chute, l'éclat s'effrite de la chair vers la pointe en cinq grains.
static func _bone_range(p: float) -> void:
	var B: Array[Color] = EffectsDrawer.BONE_SHARD
	var x := roundf(4.0 * (1.0 - (1.0 - p) * (1.0 - p)))
	if p < 0.88:
		_bone(L(x, 0.0), _d, floori(10.0 * (1.0 - p) - 3.0))
	else:
		D(L(x + 1.0, 0.0), Color.WHITE, _fade((p - 0.88) / 0.12, 2.0))
	_shadow(_ground(x), roundi(3.0 * (1.0 - p)))
	for i in 5:
		var st := i * 0.13
		if p > st:
			var e := (p - st) / (1.0 - st)
			var t := e * 0.36
			D(L(x - 6.0 + i * 1.6 - e * 3.0, float(i % 3 - 1)) + Vector2(0.0, t * 14.0 + t * t * 120.0), B[1] if i < 2 else B[2] if i < 4 else B[3], 0.95 * (1.0 - e))


## Étincelle : croix blanche, trois étincelles bleutées en arrière, l'éclat ricoche et tombe.
static func _iron_wall(a: float, p: float) -> void:
	var S: Array[Color] = EffectsDrawer.ARROW_SPARK
	var x := _w - 2.0
	if a < 0.05:
		_pts(L(x, 0.0), EffectsDrawer.CROSS5, Color.WHITE)
		_lpts(x, 0.0, DIAG_BACK, Color("#ffe08a"))
	var V: Array[Vector2] = [Vector2(-70, -44), Vector2(-86, 8), Vector2(-36, -78)]
	for v: Vector2 in V:
		var s := _shot(x, 0.0, v.x, v.y, 0.0, a, false)
		D(s, Color.WHITE if p < 0.3 else S[3] if p < 0.6 else S[2], _fade(p, 1.6))
		D(s - (_d * v.x - _n * v.y) * 0.012, S[1], _fade(p, 1.1))
	var r := _shot(x, 0.0, -46.0, -22.0, 240.0, a)
	D(r, EffectsDrawer.PILUM_IRON[1], _fade(p, 2.0))
	D(r + Vector2(1, 0), EffectsDrawer.PILUM_IRON[0], _fade(p, 2.0))


## Reflet : une croix, un point de fer clair, un point sombre, rien.
static func _iron_range(p: float) -> void:
	var I: Array[Color] = EffectsDrawer.PILUM_IRON
	var c := L(3.0 * p, 0.0)
	if p < 0.35:
		_pts(c, [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)], I[0])
		P(c - _d * 2.0, I[0])
		P(c, I[1])
		P(c + _d, Color.WHITE)
		_pts(c, [Vector2(0, -2), Vector2(0, 2)], Color.WHITE)
		P(c + _d * 2.0, Color.WHITE)
	elif p < 0.7:
		P(c, I[1])
		P(c - _d, I[0])
	else:
		D(c, I[0], _fade((p - 0.7) / 0.3, 1.5))


# ---------------------------------------------------------------- Martyre

## Fêlure du dôme : trait blanc qui s'allonge sur la paroi, quatre paillettes glissent, deux retombent.
static func _or_wall(a: float, p: float) -> void:
	var m := roundi(2.0 + p * 9.0)
	for j in range(-m, m + 1):
		D(L(_w, j), LIGHT[6] if absi(j) < m * 0.5 else LIGHT[4], _fade(p, 1.5) - absf(j) / m * 0.3)
	if a < 0.06:
		_oell(_w - 3.0, 0.0, 2.0, 5.0, Color.WHITE, -1.0, true, 0.5)
	for sg: float in [-1.0, 1.0]:
		for i in 2:
			var y := sg * (3.0 + a * (46.0 - i * 20.0))
			D(L(_w - 1.0 - i, y), LIGHT[3] if i else LIGHT[5], _fade(p, 1.5))
			D(L(_w - 1.0 - i, y - sg), LIGHT[4], _fade(p, 0.9))
	var V: Array[Vector2] = [Vector2(-30, -30), Vector2(-44, -4)]
	for v: Vector2 in V:
		D(_shot(_w - 3.0, 0.0, v.x, v.y, 150.0, a), LIGHT[5], _fade(p, 1.6))


## Poussière d'or : l'éclat se resserre en losange, scintille en croix, la poussière monte.
static func _or_range(p: float) -> void:
	var fx := 3.0 * minf(1.0, p * 2.0)
	var c := L(fx, 0.0)
	if p < 0.4:
		var s := 1.0 - p * 2.0
		_oell(fx, 0.0, 1.0 + 4.5 * s, 0.6 + 2.2 * s, Color.WHITE, -1.0, true, 0.55)
	if p > 0.25 and p < 0.5:
		_pts(c, EffectsDrawer.CROSS5, Color.WHITE)
		_cross2(c, LIGHT[5])
	if p >= 0.4:
		var e := (p - 0.4) / 0.6
		D(c + Vector2(0.0, -e * 10.0), LIGHT[4], 1.0 - e)
		D(c + Vector2(-2.0, 1.0 - e * 6.0), LIGHT[3], 0.7 * (1.0 - e))
		D(c + Vector2(2.0, -1.0 - e * 7.0), LIGHT[5], 0.7 * (1.0 - e))


# ---------------------------------------------------------------- Balles de l'Arbalestrie

## Arcs sur la roche : éclat blanc, deux micro-éclairs le long de la paroi, trois grains de poussière.
static func _spirit_wall(a: float, p: float) -> void:
	var C: Array[Color] = EffectsDrawer.CY
	if p < 0.35:
		_pts(L(_w - 2.0, 0.0), EffectsDrawer.CROSS5, C[5])
		_lpts(_w - 2.0, 0.0, DIAG_BACK, C[3])
	var m := mini(6, int(a * 60.0))
	for sg: float in [-1.0, 1.0]:
		for k in m + 1:
			D(L(_w - 1.0 - (1.0 if _h(k, sg + 3.0) > 0.5 else 0.0), sg * (1.0 + k)), Color("#e9fbff") if k == m else C[3], _fade(p, 1.6))
	var V: Array[Vector2] = [Vector2(-12, 4), Vector2(-6, 12), Vector2(-18, -6)]
	for v: Vector2 in V:
		D(_shot(_w - 2.0, 0.0, v.x, v.y, 90.0, a), Color("#c7c7bd"), 0.7 * _fade(p, 1.3))


## Anneau qui s'ouvre : le cœur d'encre s'éteint, le liseré cyan s'ouvre en anneau tramé.
static func _spirit_range(a: float, p: float) -> void:
	var C: Array[Color] = EffectsDrawer.CY
	var c := L(2.0 * p, 0.0)
	if p < 0.4:
		P(c, Color("#5b6068") if p < 0.2 else INK)
	var r := 2.0 + p * 4.0
	_ring(c, r, C[4] if p < 0.4 else C[3] if p < 0.7 else C[2], _fade(p, 1.3), ceili(r * 5.0))
	if p < 0.6:
		var an := _h(float(int(a * 30.0)), 1.0) * TAU
		P(c + Vector2.from_angle(an) * (r + 1.0), Color("#e9fbff"))
		P(c + Vector2.from_angle(an + 0.5) * (r + 2.0), C[3])


## Demi-anneau de chaleur : étoile, demi-anneau du côté libre, trois braises au pied du mur, brûlure.
static func _indra_wall(a: float, p: float) -> void:
	var C: Array = EffectsDrawer.AMMO_PAL["indra"]
	var x := _w - 2.0
	_oell(_w + 1.0, 0.0, 1.6, 3.4, C[0], 0.9 * _fade(p, 1.2))
	if p < 0.25:
		for i in range(-3, 4):
			var col: Color = C[5] if absi(i) < 2 else C[3]
			if i <= 1:
				P(L(x + i, 0.0), col)
			P(L(x, i), col)
		_lpts(x, 0.0, DIAG_BACK, C[4])
	var r := 3.0 + p * 6.0
	for k in 11:
		var t := -PI / 2.0 + k / 10.0 * PI
		D(L(_w - 1.0 - cos(t) * r * 0.6, sin(t) * r), C[2], 0.8 * (1.0 - p))
	var V: Array[Vector2] = [Vector2(-28, -40), Vector2(-46, -22), Vector2(-16, -56)]
	for i in 3:
		var s := _shot(x, 0.0, V[i].x, V[i].y, 190.0, a, false)
		if s.y > _gy:
			s.y = _gy - absf(sin(a * 13.0 + i)) * 2.0
		D(s, C[3] if i % 2 else C[4], _fade(p, 1.4))


## Braise qui s'éteint : le cœur passe de l'orange au noir, deux filets de fumée, escarbilles envolées.
static func _indra_range(a: float, p: float) -> void:
	var C: Array = EffectsDrawer.AMMO_PAL["indra"]
	var c := L(3.0 * minf(1.0, p * 1.5), 0.0).round()
	if p > 0.2:
		var e := (p - 0.2) / 0.8
		D(c + Vector2(-1.0, -3.0 - e * 9.0), SMOKE[1], 0.7 * (1.0 - e))
		D(c + Vector2(1.0 + sin(a * 14.0), -2.0 - e * 6.0), SMOKE[2], 0.7 * (1.0 - e))
	D(c - _d * (4.0 + a * 12.0) + Vector2(0.0, -1.0 - a * 16.0), C[4], _fade(p, 1.2))
	D(c - _d * (6.0 + a * 8.0) + Vector2(0.0, 1.0 - a * 10.0), C[3], _fade(p))
	_ga = 1.0 if p < 0.75 else _fade((p - 0.75) / 0.25)
	var inner: Color = C[3] if p < 0.25 else C[2] if p < 0.5 else C[1] if p < 0.75 else C[0]
	for b in range(-2, 3):
		for i in range(-2, 3):
			if absi(i) == 2 and absi(b) == 2:
				continue
			P(c + Vector2(i, b), inner if absi(i) < 2 and absi(b) < 2 else INK)
	if p < 0.25:
		P(c, C[5])
	elif p < 0.5:
		P(c, C[3])
	_ga = 1.0


static func _seed(c: Vector2) -> void:
	var C: Array = EffectsDrawer.AMMO_PAL["medeina"]
	_rim(c, C[4])
	_pts(c, EffectsDrawer.RING8, INK)
	P(c, C[3])
	D(c + Vector2(-1, -1), C[4], 0.8)


## Feuilles qui tombent : la graine se fend, ses deux feuilles descendent en se balançant, sève sur la roche.
static func _medeina_wall(a: float, p: float) -> void:
	var C: Array = EffectsDrawer.AMMO_PAL["medeina"]
	var x := _w - 2.0
	if p < 0.25:
		_pts(L(x, 0.0), EffectsDrawer.CROSS5, C[5])
		_lpts(x, 0.0, DIAG_BACK, C[3])
	_lpts(_w, 0.0, [Vector2(0, -1), Vector2(0, 0), Vector2(1, 1)], C[2], 0.9 * _fade(p, 1.3))
	var f := _fade(p, 1.6)
	for i in 2:
		var sw := sin(a * 13.0 + i * 2.4)
		var q := L(x - 2.0 - i * 3.0 - a * 8.0, -1.0 + i * 2.0) + Vector2(sw * 2.0, a * 24.0)
		q.y = minf(q.y, _gy)
		D(q, C[4], f)
		D(q + Vector2(1.0 if sw > 0.0 else -1.0, (1.0 if i else -1.0) * (1.0 if absf(sw) < 0.5 else 0.0)), C[3], f)


## Pousse : la graine tombe au sol, une tige de 3 px en sort, deux feuilles s'ouvrent.
static func _medeina_range(a: float, p: float) -> void:
	var C: Array = EffectsDrawer.AMMO_PAL["medeina"]
	var T := 0.13
	if a < T:
		var k := a / T
		_seed((L(2.0 * k, 0.0) + Vector2(0.0, (_gy - 1.0 - _o.y) * k * k)).round())
		return
	var g := _ground(2.0).round()
	var m := roundi(clampf((a - T) / 0.2, 0.0, 1.0) * 3.0)
	_ga = _fade((p - 0.75) / 0.25)
	_pts(g, [Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)], INK)
	P(g, C[3])
	for j in range(1, m + 1):
		P(g + Vector2(0, -j), C[3] if j == m else C[2])
	if a > T + 0.2:
		var open := a - T - 0.2 >= 0.1
		var up := 0.0 if open else 1.0
		P(g + Vector2(-1.0, -3.0 - up), C[4])
		P(g + Vector2(1.0, -3.0 - up), C[4])
		if open:
			P(g + Vector2(-2, -4), C[3])
			P(g + Vector2(2, -4), C[3])
			P(g + Vector2(0, -4), C[5])
	_ga = 1.0


## Glyphe gravé : éclat blanc, glyphe en croix sur la roche, deux tirets le long de la paroi, deux éclats de marbre.
static func _sigil_wall(a: float, p: float) -> void:
	var C: Array = EffectsDrawer.AMMO_PAL["sigil"]
	var f := _fade(p, 1.4)
	if p < 0.3:
		_pts(L(_w - 2.0, 0.0), EffectsDrawer.CROSS5, C[5])
	_lpts(_w + 2.0, 0.0, [Vector2(0, -2), Vector2(0, -1), Vector2(0, 0), Vector2(0, 1), Vector2(0, 2), Vector2(-1, 0), Vector2(1, 0),
		Vector2(-1, -2), Vector2(1, 2)], C[5] if p < 0.3 else C[4], f)
	var dd := 2.0 + p * 5.0
	D(L(_w - 1.0, -dd), C[4], f)
	D(L(_w - 1.0, dd), C[4], f)
	D(_shot(_w - 2.0, 0.0, -22.0, -26.0, 210.0, a), C[3], _fade(p, 1.6))
	D(_shot(_w - 2.0, 0.0, -34.0, -6.0, 210.0, a), C[2], _fade(p, 1.6))


## Marbre qui s'effrite : la bille s'arrête, son glyphe s'écarte, trois grains gris tombent droit.
static func _sigil_range(a: float, p: float) -> void:
	var C: Array = EffectsDrawer.AMMO_PAL["sigil"]
	var c := _o.round()
	var dd := roundf(2.0 + p * 4.0)
	_pts(c, [Vector2(-dd, 0), Vector2(dd, 0), Vector2(0, -dd), Vector2(0, dd)], C[4], _fade(p, 1.2))
	if p < 0.3:
		_rim(c, C[5])
		_pts(c, [Vector2(-1, -1), Vector2(0, -1), Vector2(-1, 0)], C[3])
		_pts(c, [Vector2(1, -1), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)], INK)
		P(c, C[4])
		var ph := int(a * 24.0) % 3
		P(c + Vector2(-1 + ph, -1 + mini(ph, 1)), C[5])
		return
	var e := a - float(DUR["sigil"][1]) * 0.3
	for i in 3:
		D(Vector2(c.x + (i - 1) * (1.0 + e * 14.0), minf(_gy, c.y + e * e * (260.0 - i * 60.0))), C[3 - i], _fade((p - 0.3) / 0.7, 1.5))


## Orbite plaquée : l'anneau d'orbite se rabat sur la paroi en ovale, l'étoile est éjectée vers le haut.
static func _aether_wall(a: float, p: float) -> void:
	var C: Array = EffectsDrawer.AMMO_PAL["aether"]
	var x := _w - 2.0
	if p < 0.3:
		_lpts(x, 0.0, [Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)], C[4])
		P(L(x, 0.0), C[5])
	var ry := 3.0 + p * 5.0
	for k in 11:
		var t := PI / 2.0 + k / 10.0 * PI
		D(L(_w - 1.0 + cos(t) * 1.6, sin(t) * ry), C[3] if p < 0.4 else C[2], 0.85 * (1.0 - p))
	var s := _shot(x, 0.0, -20.0, -58.0, 70.0, a, false)
	D(s, C[5], _fade(p, 1.8))
	D(s + Vector2(1, 2), C[3], _fade(p, 1.2))
	if p > 0.5 and p < 0.7:
		_pts(s, [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)], C[4])


## Implosion : l'anneau d'orbite se resserre sur l'astre, qui scintille en croix puis se trame.
static func _aether_range(a: float, p: float) -> void:
	var C: Array = EffectsDrawer.AMMO_PAL["aether"]
	var c := L(2.0 * minf(1.0, p * 2.0), 0.0).round()
	if p < 0.5:
		var s := 1.0 - p / 0.5
		var rx := 3.5 * s + 1.2
		var ry := 1.5 * s + 1.2
		for k in 12:
			var t := k / 12.0 * TAU
			var q := Vector2(roundf(cos(t) * rx), roundf(sin(t) * ry))
			if absf(q.x) > 1.0 or absf(q.y) > 1.0:
				D(c + q, C[2] if p < 0.25 else C[4], 0.6 + p)
		_rim(c, C[4])
		_pts(c, EffectsDrawer.RING8, INK)
		P(c, C[4])
		P(c + Vector2(roundf(cos(a * 30.0) * (3.5 * s + 1.0)), roundf(sin(a * 30.0) * (1.5 * s + 1.0))), C[5])
	elif p < 0.72:
		_pts(c, EffectsDrawer.CROSS5, C[5])
		if p < 0.62:
			_cross2(c, C[4])
	else:
		D(c, C[3], _fade((p - 0.72) / 0.28, 1.4))
