class_name OpeningView
extends Node2D
## Rendu de la séquence d'ouverture (sim/opening.gd), en pixels natifs du monde. Deux nœuds :
##   ground = false : sous les sprites → remparts de la brèche (8.3 « Arc gardé »), onde rose au sol ;
##   ground = true est l'inverse : air → portail d'arrivée (1.2), bouclier « film de savon » (3.3), canons de
##   Byrsa (6.1), obus, impacts, fissures et contraction (7.1), canons renversés, fumées.
## Les servants des canons reprennent l'atlas ennemi « shield » (assets/imported/enemies).

const K0 := Color("#0b090b")
const GOLD := Color("#e0b048")
const GOLD2 := Color("#a87a26")
const BRZ := Color("#8a5f2e")
const BRZ_HI := Color("#b07a3a")
const BRZ_LO := Color("#5c3d1d")
const WOOD := Color("#5a3b22")
const WOOD_HI := Color("#7a5332")
const WOOD_LO := Color("#3b2614")
const SERVANT_WALK := preload("res://assets/imported/enemies/shield_walk.png")
const SERVANT_IDLE := preload("res://assets/imported/enemies/shield_idle.png")
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const FRAMES := 6

var world: World
var ground := false
static var _tex := {}


func _process(_delta: float) -> void:
	visible = GameState.opening_stage != "" or (world and world.terrain_state.breach_open)
	if visible:
		queue_redraw()


static func _h(a: int, b: int) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)


func _nat(x: float, y: float, z: float) -> Vector2:
	return Proj.nat(x, y, z).round()


func _draw() -> void:
	if ground:
		_draw_ramparts()
		_draw_ground_wave()
		return
	var s := GameState.opening_stage
	if s == "arrival":
		_draw_portal()
	_draw_shield()
	_draw_cannons()


# ---------------------------------------------------------------- Portail d'arrivée (1.2 Arcs au sol)

func _bolt(a: Vector2, b: Vector2, col: Color, seg: int, seed: int, jit := 5.0) -> void:
	var prev := a
	for i in range(1, seg + 1):
		var f := float(i) / seg
		var p := a.lerp(b, f)
		if i < seg:
			p += Vector2(_h(seed, i) - 0.5, _h(seed, i + 40) - 0.5) * jit
		draw_line(prev.round(), p.round(), col, 1.0)
		prev = p


func _draw_portal() -> void:
	var t := Opening.elapsed()
	var o: Array = Opening.ARR_OPEN
	var c: Array = Opening.ARR_CLOSE
	var open := smoothstep(o[0], o[1], t) * (1.0 - smoothstep(c[0], c[1], t))
	var land := _nat(Opening.LAND.x, 0.0, Opening.LAND.y)
	var ctr := _nat(Opening.PORTAL_AT.x, 2.6, Opening.PORTAL_AT.y)
	var r := open * 18.0
	var flick := floori(t * 14.0)
	if open > 0.0:
		_ellipse(land + Vector2(0, -2), r * 1.6, r * 0.45, Color(0.87, 0.91, 1.0, 0.3 * open))
	if t > c[1]:
		_ellipse(land + Vector2(0, 1), 12.0, 3.5, Color(0.1, 0.08, 0.09, 0.5 * (1.0 - clampf((t - c[1]) / 6.0, 0.0, 1.0))))
	if r > 1.0:
		_ellipse(ctr, r + 4, r + 4, Color(1, 1, 1, 0.11))
		_ellipse(ctr, r + 1, r + 1, Color(0.81, 0.85, 0.92, 0.35))
		_ellipse(ctr, r, r, K0)
		_ellipse(ctr, r - 1, r - 1, Color("#dfe5ef"))
		_ellipse(ctr + Vector2(0, r * 0.35), r * 0.8, r * 0.45, Color("#aab4c4"))
		_ellipse(ctr + Vector2(0, r * 0.45), r * 0.55, r * 0.25, Color("#8691a3"))
		_ellipse(ctr + Vector2(-r * 0.35, -r * 0.4), r * 0.32, r * 0.22, Color.WHITE)
		for i in 6:
			var a := i * 1.047 + t * 0.6
			_ellipse(ctr + Vector2(cos(a), sin(a)) * r * 0.55, 1.5, 1.5, Color("#f5f8ff"))
		for i in 3:
			var a := t * 3.0 + i * TAU / 3.0
			_bolt(ctr + Vector2(cos(a), sin(a) * 0.9) * r, ctr + Vector2(cos(a + 0.7), sin(a + 0.7) * 0.9) * (r + 7), Color.WHITE if i % 2 else Color("#bcd8ff"), 4, flick * 7 + i)
		# Décharges qui frappent les dalles autour du point d'atterrissage.
		if _h(flick, 3) < 0.55:
			var a := _h(flick, 4) * PI
			var to := land + Vector2((_h(flick, 5) - 0.5) * 70.0, 2.0 + _h(flick, 6) * 10.0)
			_bolt(ctr + Vector2(cos(a) * r * 0.8, r * 0.6), to, Color("#e4eeff"), 6, flick, 7.0)
			draw_rect(Rect2(to.round() - Vector2(1, 0), Vector2(3, 1)), Color(1, 1, 1, 0.8))
	# Implosion en un point.
	var kc := clampf((t - c[1] + 0.05) / 0.3, 0.0, 1.0)
	if kc > 0.0 and kc < 1.0:
		_ellipse(ctr, 2.0 + 6.0 * (1.0 - kc), 2.0 + 6.0 * (1.0 - kc), Color.WHITE)
		draw_rect(Rect2(ctr + Vector2(-30.0 * (1.0 - kc), 0), Vector2(60.0 * (1.0 - kc), 1)), Color.WHITE)
	# Bouffées de halètement.
	if t > Opening.ARR_EJECT + 1.0 and t < Opening.ARR_RISE and sin(t * 5.5) > 0.6:
		draw_rect(Rect2(land + Vector2(5, -30), Vector2(2, 1)), Color(0.91, 0.93, 0.94, 0.6))
		draw_rect(Rect2(land + Vector2(7, -31), Vector2(1, 1)), Color(0.91, 0.93, 0.94, 0.6))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ring(c: Vector2, rx: float, ry: float, col: Color, w := 1.0) -> void:
	if rx < 0.5:
		return
	draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	draw_arc(Vector2.ZERO, rx, 0.0, TAU, 48, col, w / maxf(0.2, ry / rx) if ry < rx else w)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- Bouclier (3.3 Film de savon)

static func _radius() -> int:
	return roundi(Opening.SHIELD_R * Proj.K)


static func _height() -> int:
	return roundi(Opening.SHIELD_H * Proj.KH)


## Mur du dôme vu de face (arrière ou avant), FRAMES images : bandes irisées qui tournent lentement,
## rose pâle dominant, en paliers tramés comme le reste du jeu.
static func shield_textures(is_front: bool) -> Array:
	if _tex.has(is_front):
		return _tex[is_front]
	var r := _radius()
	var hp := _height()
	var w := 2 * r + 1
	var h := r + hp + 3
	var out: Array = []
	for f in FRAMES:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var ph := TAU * f / FRAMES
		for x in w:
			var dx := x - r
			var nx := float(dx) / r
			var gy := sqrt(maxf(0.0, float(r * r - dx * dx)))
			var base := roundi(hp + gy) if is_front else roundi(r + hp - gy)
			var edge := pow(absf(nx), 6.0)
			for k in hp:
				var y := base - k
				if y < 0 or y >= h:
					continue
				var hh := float(k) / hp
				var film := sin(nx * 4.0 + sin(hh * 2.5 + ph) * 2.0 + ph) + sin(hh * 5.0 - ph * 0.5 + nx)
				var hue := (315.0 + film * 38.0) / 360.0
				var a := (0.1 + 0.12 * (film * 0.5 + 0.5) + 0.55 * edge) * (1.0 - hh * 0.55) * (0.75 if is_front else 1.0)
				var th: float = (BAYER[y % 4][x % 4] + 0.5) / 16.0
				if a * 2.2 > th:
					img.set_pixel(x, y, Color.from_hsv(fposmod(hue, 1.0), 0.28, 1.0, 0.55 if a > 0.3 else 0.32))
			# Liseré au sol.
			for k in 2:
				var y := base - k + 1
				if y >= 0 and y < h:
					img.set_pixel(x, y, Color.from_hsv(fposmod((330.0 + 25.0 * sin(nx * 6.0 + ph)) / 360.0, 1.0), 0.3, 1.0, 0.85 if k == 0 else 0.5))
			# Sommet du mur : bord plus dense.
			var top := base - hp + 1
			if top >= 0 and top < h:
				img.set_pixel(x, top, Color(1.0, 0.9, 0.95, 0.45))
		out.append(ImageTexture.create_from_image(img))
	_tex[is_front] = out
	return out


func _shield_strength() -> float:
	if not GameState.shield_up:
		return 0.0
	return clampf((GameState.sim_time - GameState.shield_at) / 1.0, 0.0, 1.0)


func _draw_shield() -> void:
	var s := _shield_strength()
	if s <= 0.0:
		return
	var t := GameState.sim_time
	var blast := GameState.opening_stage == "blast"
	var bt := Opening.elapsed()
	var shrink := 0.0
	var pulse := 1.0
	if blast:
		shrink = smoothstep(Opening.CONTRACT[0], Opening.CONTRACT[1], bt) * 0.12
		if bt > Opening.CONTRACT[0]:
			pulse = 1.0 + 0.3 * sin(t * 40.0) * clampf((bt - Opening.CONTRACT[0]) / (Opening.BURST - Opening.CONTRACT[0]), 0.0, 1.0)
	var c := _nat(Opening.SHIELD_C.x, 0.0, Opening.SHIELD_C.y)
	var r := _radius()
	var hp := _height()
	var f := floori(t * 3.0) % FRAMES
	var sc := 1.0 - shrink
	draw_set_transform(c, 0.0, Vector2(sc, sc))
	var col := Color(1, 1, 1, clampf(s * pulse, 0.0, 1.0))
	draw_texture(shield_textures(false)[f], Vector2(-r, -r - hp), col)
	draw_texture(shield_textures(true)[f], Vector2(-r, -hp), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Impacts : onde rose qui s'élargit sur la paroi avant.
	for i in Opening.CANNONS.size():
		var fp := Opening.fire_phase(i)
		if fp < Opening.SHELL_FLIGHT:
			continue
		var age := (fp - Opening.SHELL_FLIGHT) / (1.0 - Opening.SHELL_FLIGHT)
		var ip := Opening.impact(i)
		var p := _nat(ip.x, ip.y, ip.z)
		_ring(p, 2.0 + age * 26.0, 1.0 + age * 14.0, Color(1.0, 0.86, 0.93, 0.8 * (1.0 - age)))
		if age < 0.25:
			_ellipse(p, 5.0 * (1.0 - age * 3.0) + 1.0, 3.0, Color(1.0, 0.97, 0.85, 1.0 - age * 4.0))
		if age < 0.5:
			for k in 10:
				var a := _h(i * 31 + k, 2) * TAU
				var d := (12.0 + _h(k, i) * 14.0) * age
				draw_rect(Rect2((p + Vector2(cos(a) * d, sin(a) * d * 0.6 + 30.0 * age * age)).round(), Vector2.ONE), Color("#ffc070"))
	# Fissures blanches avant la rupture.
	if blast:
		var cr := clampf((bt - Opening.CRACK[0]) / (Opening.CRACK[1] - Opening.CRACK[0]), 0.0, 1.0)
		for k in roundi(cr * 14.0):
			var x0 := (_h(k, 9) - 0.5) * 1.8 * r * sc
			var gy := sqrt(maxf(0.0, r * r * sc * sc - x0 * x0))
			var p0 := c + Vector2(x0, gy - 4.0)
			var p1 := p0 + Vector2((_h(k, 10) - 0.5) * 30.0, -hp * sc * (0.4 + _h(k, 11) * 0.5))
			_bolt(p0, p1, Color(1, 1, 1, 0.9), 5, k * 13, 8.0)
		if bt > Opening.CONTRACT[0]:
			for k in 10:
				var a := _h(k, 20) * PI
				var p := c + Vector2(cos(a) * r * sc * 0.95, sin(a) * r * sc * 0.47 - _h(k, 21) * hp)
				var u := fmod(t * 3.0 + k * 0.1, 1.0)
				draw_rect(Rect2((p + Vector2(0, -u * 12.0)).round(), Vector2.ONE), Color(1.0, 0.82, 0.9, 1.0 - u))


func _draw_ground_wave() -> void:
	if GameState.opening_stage != "blast":
		return
	var k := clampf((Opening.elapsed() - Opening.BURST) / 1.6, 0.0, 1.0)
	if k <= 0.0 or k >= 1.0:
		return
	var c := _nat(Opening.SHIELD_C.x, 0.0, Opening.SHIELD_C.y)
	var cols := [[0.0, Color("#ffc4dc"), 3.0], [0.08, Color("#f2c0ff"), 2.0], [0.16, Color("#ffd6e6"), 1.0]]
	for e: Array in cols:
		var kk := clampf(k - e[0], 0.0, 1.0)
		if kk > 0.0:
			_ring(c, 40.0 + kk * 300.0, 12.0 + kk * 140.0, Color(e[1], 1.0 - kk), e[2])
	if k < 0.35:
		_ellipse(c, 40.0 + k * 300.0, 12.0 + k * 140.0, Color(1.0, 0.84, 0.9, 0.45 * (1.0 - k / 0.35)))


# ---------------------------------------------------------------- Canons de Byrsa (6.1)

func _cannon(at: Vector2, rec: float, rot := 0.0) -> void:
	draw_set_transform(at, rot, Vector2.ONE)
	if rot == 0.0:
		_ellipse(Vector2(0, 4), 13.0, 4.0, Color(0, 0, 0, 0.45))
	var R := func(x: float, y: float, w: float, h: float, c: Color) -> void: draw_rect(Rect2(x, y, w, h), c)
	R.call(-9, -6, 18, 11, K0); R.call(-8, -5, 16, 9, WOOD); R.call(-8, -5, 16, 1, WOOD_HI); R.call(-8, 2, 16, 2, WOOD_LO)
	R.call(-1, 4, 2, 6, K0); R.call(-1, 5, 1, 5, WOOD)
	for sgn in [-1, 1]:
		R.call(sgn * 11 - 3, -6, 6, 12, K0); R.call(sgn * 11 - 2, -5, 4, 10, WOOD_LO); R.call(sgn * 11 - 2, -1, 4, 1, GOLD2); R.call(sgn * 11 - 1, -5, 1, 10, Color("#6a4628"))
	var by := -22.0 + rec
	R.call(-4, by, 8, 20, K0); R.call(-3, by + 1, 6, 18, BRZ); R.call(-3, by + 1, 2, 18, BRZ_HI); R.call(2, by + 1, 1, 18, BRZ_LO)
	R.call(-4, by + 5, 8, 2, GOLD); R.call(-4, by + 12, 8, 2, GOLD); R.call(-3, by + 5, 1, 2, Color("#fff0b0"))
	R.call(-5, by - 2, 10, 4, K0); R.call(-4, by - 1, 8, 2, GOLD); R.call(-1, by - 1, 2, 1, K0)
	R.call(-2, -3, 4, 4, K0); R.call(-1, -2, 2, 2, GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _servant(tex: Texture2D, frame: int, at: Vector2, flip: bool, rot := 0.0) -> void:
	var i := posmod(frame, 24)
	var src := Rect2((i % 12) * 40, (i / 12) * 42, 40, 42)
	if rot == 0.0:
		_ellipse(at, 6.0, 2.0, Color(0, 0, 0, 0.4))
	draw_set_transform(at.round(), rot, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect_region(tex, Rect2(-15, -40, 40, 42), src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _smoke(at: Vector2, r: float, a: float, seed: int) -> void:
	if a <= 0.0:
		return
	for i in 7:
		var o := Vector2((_h(seed, i) - 0.5) * r * 1.4, (_h(seed, i + 9) - 0.5) * r * 0.8)
		var g := 0.55 + _h(seed, i + 20) * 0.12
		_ellipse((at + o).round(), r * (0.4 + _h(seed, i + 30) * 0.4), r * (0.3 + _h(seed, i + 40) * 0.3), Color(g, g * 0.97, g * 0.93, a * (0.5 + _h(seed, i + 50) * 0.5)))


func _draw_cannons() -> void:
	var s := GameState.opening_stage
	if s != "siege_intro" and s != "siege" and s != "blast":
		return
	var t := GameState.sim_time
	var bt := Opening.elapsed()
	var blown := s == "blast" and bt >= Opening.BURST
	for i in Opening.CANNONS.size():
		var slot: Vector2 = Opening.CANNONS[i]
		var k := Opening.cannon_arrival(i)
		if k < 0.0:
			continue
		var at := _nat(slot.x, 0.0, slot.y + Opening.CANNON_FROM * (1.0 - k))
		if blown:
			var f := smoothstep(Opening.BURST + 0.05 + i * 0.04, Opening.BURST + Opening.FLING, bt)
			var dx := (slot.x - Opening.SHIELD_C.x) * 4.0 * f
			var lift := sin(f * PI) * 16.0
			var rot := f * ((i - 1) * 1.8 + 0.9)
			var fade := 1.0 - clampf((bt - Opening.BURST - 3.0) / 2.5, 0.0, 1.0)
			var p := at + Vector2(dx, 55.0 * f - lift)
			if fade > 0.0:
				_cannon(p.round(), 0.0, rot)
				_servant(SERVANT_IDLE, 0, at + Vector2(22.0 + dx * 1.3, 8.0 + 60.0 * f - lift * 0.6), true, f * 1.4 + 0.2)
			_smoke(p + Vector2(0, 2), 5.0, 0.4 * (1.0 - clampf((bt - Opening.BURST - 1.1) / 3.0, 0.0, 1.0)), i + 20)
			continue
		var moving := k < 1.0
		var fp := Opening.fire_phase(i)
		var rec := 4.0 * (1.0 - fp / 0.1) if fp >= 0.0 and fp < 0.1 else 0.0
		var fr := floori(t * (20.0 if moving else 10.0)) + i * 5
		if moving:
			_servant(SERVANT_WALK, fr, at + Vector2(-9, 8), false)
			_servant(SERVANT_WALK, fr + 7, at + Vector2(9, 8), true)
		_cannon(at, rec)
		if not moving:
			_servant(SERVANT_IDLE, fr, at + Vector2(16, 6), true)
		# Bouche à feu, fumée, obus en cloche vers le bouclier.
		if fp >= 0.0:
			if fp < 0.07:
				var m := 1.0 - fp / 0.07
				var rr := 2.0 + m * 5.0
				_ellipse(at + Vector2(0, -25), rr + 2.0, rr, Color(1.0, 0.81, 0.38, 0.5))
				_ellipse(at + Vector2(0, -25), rr, rr * 0.7, Color("#fff3c4"))
			if fp < 0.5:
				_smoke(at + Vector2(0, -30.0 - fp * 20.0), 3.0 + fp * 10.0, 0.55 * (1.0 - fp * 2.0), i + 9)
			if fp < Opening.SHELL_FLIGHT:
				var q := fp / Opening.SHELL_FLIGHT
				var ip := Opening.impact(i)
				var to := _nat(ip.x, ip.y, ip.z)
				var from := at + Vector2(0, -26)
				var p := from.lerp(to, q) + Vector2(0, -sin(q * PI) * 34.0)
				draw_rect(Rect2(p.round() - Vector2(2, 2), Vector2(4, 4)), K0)
				draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(2, 2)), Color("#4d4a44"))
				draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(1, 1)), GOLD)
	# Mur sud soufflé : blocs projetés depuis l'entrée, puis fumée qui cache la brèche.
	if blown:
		var f := clampf((bt - Opening.BURST) / 1.4, 0.0, 1.0)
		var m := _nat(0.0, 0.0, CaveShape.mountain_edge(0.0) - 6.0)
		if f < 1.0:
			for i in 18:
				var a := -PI / 2.0 + (_h(i, 1) - 0.5) * 2.6
				var sp := 50.0 + _h(i, 2) * 120.0
				var p := m + Vector2(cos(a) * sp * f, sin(a) * sp * f * 0.4 + f * f * 70.0)
				draw_rect(Rect2(p.round(), Vector2(3, 3)), K0)
				draw_rect(Rect2(p.round(), Vector2(2, 2)), Color("#5a6170"))
		var fade := 1.0 - clampf((bt - Opening.BURST - 3.0) / 3.0, 0.0, 1.0)
		var kk := clampf((bt - Opening.BURST) / 1.6, 0.0, 1.0)
		_smoke(m, 24.0 + kk * 20.0, 0.85 * fade, 41)
		_smoke(m + Vector2(-34, 18), 16.0 + kk * 14.0, 0.6 * fade, 42)
		_smoke(m + Vector2(34, 18), 16.0 + kk * 14.0, 0.6 * fade, 43)


# ---------------------------------------------------------------- Remparts (8.3 Arc gardé)

## Terrasses (contour du dessus en unités de monde), hauteur de la face en pixels natifs.
const TERRACES := [
	[Vector2(-15.0, -77.5), Vector2(-3.5, -76.5), Vector2(-1.75, -73.5), Vector2(-3.0, -72.5), Vector2(-14.5, -74.5)],
	[Vector2(3.5, -76.5), Vector2(15.0, -77.5), Vector2(14.5, -74.5), Vector2(3.0, -72.5), Vector2(1.75, -73.5)],
]
const TERRACE_H := 12.0
const STEPS := [[Vector2(-3.75, -72.0), -1], [Vector2(2.25, -72.0), 1]]
const PAVE := Color("#4b525c")
const PAVE_LO := Color("#3a4049")
const PAVE_HI := Color("#5c6574")
const FACE := Color("#333a46")
const FACE_LO := Color("#262b34")
const MOSS := Color("#4f7a3a")


func _poly(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)


func _draw_ramparts() -> void:
	if not world or not world.terrain_state.breach_open:
		return
	for ti in TERRACES.size():
		var top := PackedVector2Array()
		for p: Vector2 in TERRACES[ti]:
			top.append(_nat(p.x, 0.0, p.y) + Vector2(0, -TERRACE_H))
		var n := top.size()
		# Faces avant : arêtes orientées vers le sud (de droite à gauche dans l'ordre du contour).
		for i in n:
			var a := top[i]
			var b := top[(i + 1) % n]
			if b.x < a.x:
				var face := PackedVector2Array([a, b, b + Vector2(0, TERRACE_H), a + Vector2(0, TERRACE_H)])
				_poly(PackedVector2Array([a + Vector2(1, -1), b + Vector2(-1, -1), b + Vector2(-1, TERRACE_H + 1), a + Vector2(1, TERRACE_H + 1)]), K0)
				_poly(face, FACE)
				_poly(PackedVector2Array([a + Vector2(0, TERRACE_H - 3), b + Vector2(0, TERRACE_H - 3), b + Vector2(0, TERRACE_H), a + Vector2(0, TERRACE_H)]), FACE_LO)
				# Joints de la paroi.
				var len := a.distance_to(b)
				for k in range(4, int(len), 7):
					var q := a.lerp(b, k / len)
					draw_rect(Rect2(q.round() + Vector2(0, 2), Vector2(1, TERRACE_H - 5)), FACE_LO)
		var outline := top.duplicate()
		for i in n:
			outline[i] += (top[i] - _centroid(top)).normalized() * 1.0
		_poly(outline, K0)
		_poly(top, PAVE)
		# Dallage : rangs décalés.
		var bb := Rect2(top[0], Vector2.ZERO)
		for p in top:
			bb = bb.expand(p)
		for y in range(int(bb.position.y) + 2, int(bb.end.y), 4):
			for x in range(int(bb.position.x) + ((y / 4) % 2) * 3, int(bb.end.x), 7):
				var p := Vector2(x, y)
				if Geometry2D.is_point_in_polygon(p, top) and Geometry2D.is_point_in_polygon(p + Vector2(6, 0), top):
					draw_rect(Rect2(p, Vector2(1, 3)), PAVE_LO)
					draw_rect(Rect2(p + Vector2(1, 0), Vector2(5, 1)), PAVE_HI if (x + y) % 3 else PAVE_LO)
		for i in n:
			draw_line(top[i], top[(i + 1) % n], PAVE_HI, 1.0)
		for i in 10:
			var p := top[floori(_h(ti, i) * n)]
			draw_rect(Rect2((p + Vector2(_h(i, ti + 3) * 6.0 - 3.0, _h(i, ti + 5) * 2.0)).round(), Vector2(2 + floori(_h(i, 7) * 3.0), 1)), MOSS)
	# Marches vers la route.
	for st: Array in STEPS:
		var b := _nat(st[0].x, 0.0, st[0].y)
		for i in 4:
			var p := b + Vector2(st[1] * i * 4 - 4, -TERRACE_H + i * 3)
			draw_rect(Rect2(p, Vector2(8, 3)), K0)
			draw_rect(Rect2(p, Vector2(8, 2)), Color("#7d858f"))
			draw_rect(Rect2(p + Vector2(0, 2), Vector2(8, 1)), Color("#3b4149"))
	# Pieux plantés au passage.
	for i in 5:
		var p := _nat(-1.5 + i * 0.75, 0.0, -71.75)
		draw_rect(Rect2(p + Vector2(0, -9), Vector2(2, 9)), K0)
		draw_rect(Rect2(p + Vector2(0, -10), Vector2(1, 2)), Color("#c9b48a"))
		draw_rect(Rect2(p + Vector2(1, -8), Vector2(1, 7)), Color("#6b4b2e"))


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()
