class_name AnchorOverload
extends Node2D
## Rendu de la surcharge de l'Ancre (sim/overload.gd ; planche ancre-surcharge-propositions.html,
## proposition 5 « Rupture du sceau ») : éclats des segments de l'anneau et éclairs redoublés, colonne
## d'ombre sous une pluie de particules qui remonte, double nova (pourpre puis noire), bouclier
## d'Énonciation cyan qui se fend puis vole en éclats, fumée, pièces d'armure soufflées qui restent au sol,
## poussière d'ardoise quand l'Ingénieur tombe à genoux. La caméra se cale entre l'Ancre et l'Ingénieur.
## La sphère soulevée et les segments éteints sont rendus par le sprite de l'orbe (shaders/orb.gdshader).
##
## Enfant de WorldOverlay : espace local = pixels de l'écran. Les calculs sont faits en pixels natifs du
## monde (Proj.nat), puis décalés de world.native_offset et agrandis ×PX, comme AnchorSpark.

const PUR: Array[Color] = [Color("#14061c"), Color("#2a0c3a"), Color("#4a1666"), Color("#6a2088"), Color("#9a3ab8"), Color("#c060e0"), Color("#e6b8ff")]
const CY: Array[Color] = [Color("#0a2a33"), Color("#12596b"), Color("#1f9fb8"), Color("#5ce8ff"), Color("#c8fbff"), Color("#ffffff")]
const SMK: Array[Color] = [Color("#0c0a10"), Color("#17141c"), Color("#221e29"), Color("#302a38"), Color("#40384a"), Color("#544a5e"), Color("#6c6276")]
const DUST: Array[Color] = [Color("#23282f"), Color("#2c323a"), Color("#373e47"), Color("#444c56"), Color("#535c67")]
const VOID := Color("#030205")
const ORB3 := Color("#170c20")
const OUTC := Color("#0a0a0c")
const WH := Color("#ffffff")
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const UNIT := 8.0
## Demi-largeur de la colonne d'ombre, en pixels natifs.
const COLUMN_W := 4.0
const GRAVITY := 190.0
## Pièces d'armure arrachées : pixels (« . » vide), décalage depuis les pieds de l'Ingénieur.
const PIECES := [
	{"s": [".bBb.", "ggGgg", "gaaag", "dgggd"], "o": Vector2(1, -35)},
	{"s": [".iI.", "iIIi", "diid"], "o": Vector2(-6, -27)},
	{"s": [".Ii.", "iIIi", "diid"], "o": Vector2(7, -27)},
	{"s": ["gGg", "ggd", "dgd"], "o": Vector2(0, -21)},
	{"s": ["gGg", "gdg", "dgd"], "o": Vector2(2, -15)},
	{"s": ["bgb", "gag", "gag", "bgb"], "o": Vector2(-7, -24)},
	{"s": ["iI", "di"], "o": Vector2(-2, -10)},
	{"s": ["Ii", "id"], "o": Vector2(3, -10)},
	{"s": ["bB.", "bab", ".bb"], "o": Vector2(7, -17)},
	{"s": ["ll.", "lLl", "bbl"], "o": Vector2(-2, -2)},
	{"s": [".ll", "lLl", "lbb"], "o": Vector2(3, -2)},
	{"s": ["ddd", "aaa", "ddd"], "o": Vector2(-6, -12)},
	{"s": ["cc", "C.", "cC"], "o": Vector2(-4, -18)},
	{"s": ["c.", "cC", ".c"], "o": Vector2(-8, -14)},
]
const DPAL := {
	"g": Color("#34343b"), "d": Color("#1a1a1e"), "G": Color("#5e5e68"), "b": Color("#d0a03c"), "B": Color("#f0cc6a"),
	"a": Color("#ffb03c"), "i": Color("#c0b490"), "I": Color("#e0d6b4"), "c": Color("#8a222c"), "C": Color("#661620"),
	"l": Color("#543a22"), "L": Color("#3e2a18"),
}

var world: World
var _px := 1.0
var _off := Vector2.ZERO
var _cam_on := false
var _cam_last := Vector2.ZERO
var _key := INF
## Pièces : {rots, x0, y0, vx, vy, dl, gy, spin, rest}, tirées une fois par événement.
var _debris: Array[Dictionary] = []
var _eng := Vector2.ZERO


func _ready() -> void:
	Events.game_reset.connect(func() -> void:
		_key = INF
		_debris.clear()
		_cam_on = false
		queue_redraw())


static func _h(a: float, b: float, s: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233 + s * 37.719) * 43758.5453
	return v - floorf(v)


static func _jr(v: float) -> float:
	return floorf(v + 0.5)


# ---------------------------------------------------------------- Boucle

func _process(delta: float) -> void:
	if world == null:
		return
	if not Overload.active():
		if _key != INF:
			_key = INF
			_debris.clear()
			queue_redraw()
		return
	if GameState.overload_at != _key:
		_key = GameState.overload_at
		_setup()
	_follow(delta)
	_px = float(world.camera.px)
	_off = world.native_offset
	queue_redraw()


func _setup() -> void:
	var u := GameState.overload_unit
	_eng = Proj.nat(u.x, 0.0, u.z)
	_cam_on = true
	_cam_last = world.camera.cam
	_debris.clear()
	var away := (_eng - Overload.ring_center()).normalized()
	if away == Vector2.ZERO:
		away = Vector2.LEFT
	for i in PIECES.size():
		var pc: Dictionary = PIECES[i]
		var s := 30.0 + _h(i, 1, 3) * 35.0
		var rows: Array = pc["s"]
		var rots: Array = [rows]
		for r in 3:
			rots.append(_rot(rots[r]))
		_debris.append({
			"rots": rots, "x0": _eng.x + pc["o"].x, "y0": _eng.y + pc["o"].y,
			"vx": away.x * s + (_h(i, 2, 3) - 0.5) * 24.0, "vy": -30.0 - _h(i, 3, 3) * 55.0 + away.y * s * 0.3,
			"dl": _h(i, 4, 3) * 0.05, "gy": _eng.y - 4.0 + _h(i, 5, 3) * 11.0,
			"spin": int(_h(i, 6, 3) * 4.0), "rest": int(_h(i, 7, 3) * 4.0),
		})


static func _rot(a: Array) -> Array:
	var h := a.size()
	var w: int = (a[0] as String).length()
	var out: Array = []
	for x in w:
		var line := ""
		for y in range(h - 1, -1, -1):
			line += (a[y] as String)[x]
		out.append(line)
	return out


## Caméra calée entre l'Ancre et l'Ingénieur jusqu'au dialogue, sauf si le joueur la déplace.
func _follow(delta: float) -> void:
	var cam := world.camera
	if not _cam_on or Overload.since_hit() >= Overload.DIALOGUE:
		return
	if cam.cam.distance_to(_cam_last) > 0.01:
		_cam_on = false
		return
	var u := GameState.overload_unit
	var goal := (u.pos() + CaveShape.CORE) * 0.5 + Vector2(0.0, -2.5)
	cam.set_view(cam.cam + (goal - cam.cam) * (1.0 - exp(-3.0 * delta)), cam.px)
	_cam_last = cam.cam


## Lumières (Lighting.providers) : lueur pourpre de l'Ancre en surcharge, bouclier et éclatement.
func lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := Overload.time()
	if t < 0.0 or t > Overload.NOVA + 8.0:
		return out
	var h := Overload.since_hit()
	var agit := _agitation(t, h)
	var core := CaveShape.CORE
	if agit > 0.0:
		out.append({"x": core.x, "z": core.y, "r": 6.0 + agit * 10.0, "rgb": Color8(192, 96, 224), "glow": 0.1 + agit * 0.2})
	var e := _eng / UNIT
	if h >= Overload.SHIELD and h < Overload.BLAST:
		out.append({"x": e.x, "z": e.y, "r": 5.0, "rgb": Color8(92, 232, 255), "glow": 0.2})
	elif h >= Overload.BLAST and h < Overload.BLAST + 0.5:
		out.append({"x": e.x, "z": e.y, "r": 9.0 * (1.0 - (h - Overload.BLAST) / 0.5), "rgb": Color8(230, 220, 255), "glow": 0.35})
	return out


## Agitation de l'Ancre : monte pendant la surcharge, se maintient pendant la colonne, puis retombe.
static func _agitation(t: float, h: float) -> float:
	if t < Overload.OV_START:
		return 0.0
	if t < Overload.COLUMN:
		var ov := (t - Overload.OV_START) / (Overload.COLUMN - Overload.OV_START)
		return ov * ov
	return 0.45 * (1.0 - _column_fade(h))


static func _column_fade(h: float) -> float:
	return clampf((h - Overload.COLUMN_FADE) / Overload.COLUMN_FADE_LEN, 0.0, 1.0)


# ---------------------------------------------------------------- Dessin

func _npx(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(_jr(x + _off.x) * _px, _jr(y + _off.y) * _px, _px, _px), c)


## Pixel tramé (opacité par seuil de Bayer, sur la grille native du monde).
func _dpx(x: float, y: float, c: Color, a := 1.0) -> void:
	if a <= 0.0:
		return
	var ix := int(_jr(x))
	var iy := int(_jr(y))
	if a >= 1.0 or a > (float(BAYER[iy & 3][ix & 3]) + 0.5) / 16.0:
		_npx(ix, iy, c)


func _line(a: Vector2, b: Vector2, c: Color, al := 1.0) -> void:
	var n := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		_dpx(p.x, p.y, c, al)


func _disc(cx: float, cy: float, r: float, c: Color, a := 1.0) -> void:
	for y in range(floori(cy - r), ceili(cy + r) + 1):
		for x in range(floori(cx - r), ceili(cx + r) + 1):
			var dd := Vector2(x + 0.5 - cx, y + 0.5 - cy).length() / r
			if dd <= 1.0:
				_dpx(x, y, c, a * (1.0 - dd * dd * 0.6))


func _ring(c: Vector2, rx: float, ry: float, col: Color, a := 1.0) -> void:
	if rx <= 0.5:
		return
	var n := maxi(12, ceili(rx * 6.5))
	for k in n:
		var t := float(k) / n * TAU
		_dpx(c.x + cos(t) * rx, c.y + sin(t) * ry, col, a)


## Éclair brisé entre a et b : cœur `core`, liseré `halo`.
func _bolt(a: Vector2, b: Vector2, seed: float, core: Color, halo: Color, amp := 2.0, al := 1.0) -> void:
	var d := a.distance_to(b)
	if d < 1.0:
		return
	var n := maxi(2, roundi(d / 2.5))
	var nrm := Vector2(-(b.y - a.y), b.x - a.x) / d
	var prev := a
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := b if k == n else a.lerp(b, t) + nrm * (_h(k, seed, 1) - 0.5) * amp * 2.0 * sin(PI * t)
		_line(prev + Vector2(1, 0), p + Vector2(1, 0), halo, 0.55 * al)
		_line(prev - Vector2(1, 0), p - Vector2(1, 0), halo, 0.55 * al)
		_line(prev, p, core, al)
		prev = p


## Éclats balistiques sans état : position calculée depuis l'instant d'émission.
func _burst(seed: float, n: int, age: float, o: Vector2, a0: float, a1: float, s0: float, s1: float, l0: float, l1: float, g: float, ground: float, cols: Array[Color]) -> void:
	if age < 0.0:
		return
	for j in n:
		var life := lerpf(l0, l1, _h(j, seed, 3))
		if age > life:
			continue
		var ang := lerpf(a0, a1, _h(j, seed, 1))
		var sp := lerpf(s0, s1, _h(j, seed, 2))
		var v := Vector2(cos(ang), sin(ang)) * sp
		var fy := ground + _h(j, seed, 4) * 7.0
		var p := _ballistic(o, v, g, fy, age)
		var q := _ballistic(o, v, g, fy, maxf(0.0, age - 0.02))
		var k := age / life
		_line(q, p, cols[0] if k < 0.25 else cols[1] if k < 0.55 else cols[2], 1.0 - k * 0.5)


static func _ballistic(o: Vector2, v: Vector2, g: float, fy: float, t: float) -> Vector2:
	var p := o + v * t + Vector2(0.0, 0.5 * g * t * t)
	if p.y > fy and fy > o.y:
		var tl := (-v.y + sqrt(maxf(0.0, v.y * v.y + 2.0 * g * (fy - o.y)))) / g
		p = Vector2(o.x + v.x * tl, fy)
	return p


func _smoke(h: float, c: Vector2, seed: float, n: int, t0: float, life0: float, spread: float, r0: float, r1: float, a0: float, rise: float, ramp: Array[Color]) -> void:
	for j in n:
		var dl := _h(j, seed, 1) * 0.1
		var life := life0 * (0.8 + _h(j, seed, 2) * 0.5)
		var age := h - t0 - dl
		if age < 0.0 or age > life:
			continue
		var k := age / life
		var ek := 1.0 - pow(1.0 - k, 3.0)
		var r := lerpf(r0, r1, ek) * (0.7 + _h(j, seed, 3) * 0.5)
		var a := pow(1.0 - k, 1.4) * a0
		var ang := _h(j, seed, 4) * TAU
		var dist := _h(j, seed, 5) * spread * (0.4 + ek * 1.3)
		var x := c.x + cos(ang) * dist
		var y := c.y + sin(ang) * dist * 0.7 - 8.0 * age * rise
		_disc(x, y, r, ramp[2], a)
		_disc(x - r * 0.25, y - r * 0.3, r * 0.55, ramp[4], a * 0.8)


func _draw() -> void:
	if world == null or not Overload.active():
		return
	var t := Overload.time()
	var h := Overload.since_hit()
	var orb := Proj.nat(CaveShape.CORE.x, 3.0 + sin(GameState.sim_time * 1.7) * 0.2, CaveShape.CORE.y)
	var lift := float(Overload.sphere_lift())
	var sphere := orb + Vector2(0.0, -8.0 - lift)
	var ring_c := orb + Vector2(0.0, 6.0)
	_debris_draw(h, false)
	if t < Overload.END + 2.0:
		_ring_shards(t, ring_c)
		_nova(t, h)
		_column(t, h, sphere)
		_arcs(t, h, sphere)
		_shield(h)
		_blast(h)
	_debris_draw(h, true)


func _ring_shards(t: float, c: Vector2) -> void:
	for k in 8:
		var b := Overload.segment_break_at(k)
		var age := t - b
		if age < 0.0 or age > 0.9:
			continue
		var ang := (k * 8 + 2) / 64.0 * TAU
		var o := c + Vector2(cos(ang) * 15.0, sin(ang) * 6.0)
		if age < 0.12:
			_disc(o.x, o.y, 2.5, PUR[6], 1.0 - age / 0.12)
		_burst(k * 7 + 3, 5, age, o, -3.0, -0.1, 15.0, 45.0, 0.4, 0.8, 200.0, o.y, [PUR[6], PUR[5], PUR[3]])


func _arcs(t: float, h: float, s: Vector2) -> void:
	var agit := _agitation(t, h)
	if agit <= 0.02:
		return
	var f := floori(GameState.sim_time * 30.0)
	var n := 1 + roundi(agit * 4.0)
	for k in n:
		if _h(k, f >> 2, 3) < 0.35:
			continue
		var ang := _h(k, f >> 2, 4) * TAU
		var len := 4.0 + agit * 10.0 + _h(k, f >> 2, 5) * 4.0
		var dir := Vector2(cos(ang), sin(ang))
		_bolt(s + dir * 11.0, s + dir * (11.0 + len), f * 13 + k, VOID, PUR[3], 2.0)
		if agit > 0.5:
			_npx(s.x + dir.x * (11.0 + len), s.y + dir.y * (11.0 + len), PUR[5])


## Colonne d'ombre : monte de la sphère jusqu'au haut de l'écran, pluie de particules qui remonte.
func _column(t: float, h: float, s: Vector2) -> void:
	var a := t - Overload.COLUMN
	var fade := _column_fade(h)
	if a < 0.0 or fade >= 1.0:
		return
	var screen_top := -_off.y - 4.0
	var base := s.y - 12.0
	var rise := 1.0 - pow(1.0 - clampf(a / 0.32, 0.0, 1.0), 3.0)
	var top := lerpf(base, screen_top, rise)
	var w := COLUMN_W * (0.45 + 0.55 * rise if a < 0.32 else 1.0 + 0.12 * sin(GameState.sim_time * 14.0)) * (1.0 - smoothstep(0.0, 1.0, fade))
	if w < 0.4:
		return
	var st := GameState.sim_time
	for y in range(maxi(floori(top), floori(screen_top)), floori(base) + 1):
		var cx := s.x + sin(y * 0.22 - st * 9.0) * 0.6
		var wy := w * (0.4 + 0.6 * clampf((y - top) / 6.0, 0.0, 1.0))
		for x in range(floori(cx - wy - 3.0), ceili(cx + wy + 3.0) + 1):
			var d := absf(x + 0.5 - cx)
			if d < wy - 0.5:
				var n := Rng.vnoise(x / 1.6, y / 5.0 + st * 10.0, 33)
				_npx(x, y, PUR[3] if n > 0.74 else ORB3 if n > 0.64 else VOID)
			elif d < wy + 0.7:
				_dpx(x, y, PUR[4], 0.9)
			elif d < wy + 2.6:
				_dpx(x, y, PUR[2], 0.45 * (1.0 - (d - wy - 0.7) / 1.9))
	# Pluie de particules qui remonte autour de la colonne.
	var ground := s.y + 22.0
	var span := ground - screen_top
	for k in 40:
		var px := s.x + (_h(k, 1, 7) - 0.5) * 30.0 * (0.5 + _h(k, 2, 7) * 0.5)
		var spd := 30.0 + _h(k, 3, 7) * 40.0
		var y := ground - fmod(a * spd + _h(k, 4, 7) * span, span)
		if y < top:
			continue
		_dpx(px, y, PUR[5] if _h(k, 5, 7) < 0.5 else PUR[4], (1.0 - fade) * 0.9)
		_dpx(px, y + 1.0, PUR[2], (1.0 - fade) * 0.6)
	# Éclat à la base, sur la sphère.
	for x in range(floori(s.x - w - 3.0), ceili(s.x + w + 3.0) + 1):
		for y in range(floori(s.y - 13.0), floori(s.y - 9.0)):
			if pow((x - s.x) / (w + 3.0), 2.0) + pow((y - s.y + 11.0) / 2.0, 2.0) <= 1.0:
				_dpx(x, y, PUR[4], 0.6 * (1.0 - fade))


## Double nova : anneau pourpre, puis anneau noir 8 px derrière.
func _nova(t: float, h: float) -> void:
	var r := (t - Overload.NOVA) * Overload.NOVA_SPEED
	var r_end := Overload.reach(_eng) + 70.0
	if r < 0.0 or r > r_end:
		return
	var a := 1.0 - smoothstep(r_end - 40.0, r_end, r)
	var c := Overload.ring_center()
	var f := Overload.FLAT
	_ring(c, r, r * f, PUR[5], a)
	_ring(c, r - 1.0, (r - 1.0) * f, PUR[4], a)
	if r > 8.0:
		_ring(c, r - 7.0, (r - 7.0) * f, PUR[3], 0.5 * a)
		_ring(c, r - 8.0, (r - 8.0) * f, VOID, a)
		_ring(c, r - 9.0, (r - 9.0) * f, VOID, a)
		_ring(c, r - 10.0, (r - 10.0) * f, PUR[2], 0.6 * a)


## Bouclier d'Énonciation : se lève juste avant l'impact, se fend, puis vole en éclats.
func _shield(h: float) -> void:
	var c := _eng + Vector2(1.0, -22.0)
	if h >= Overload.SHIELD and h < Overload.BLAST:
		var s := 1.0 - pow(1.0 - clampf((h - Overload.SHIELD) / 0.15, 0.0, 1.0), 3.0)
		var rx := 14.0 * s
		var ry := 23.0 * s
		var fl := (0.4 if floori(GameState.sim_time * 30.0) % 2 else 1.0) if h > 0.2 else 1.0
		for y in range(floori(c.y - ry), ceili(c.y + ry) + 1):
			for x in range(floori(c.x - rx), ceili(c.x + rx) + 1):
				var d := pow((x - c.x) / maxf(rx, 0.1), 2.0) + pow((y - c.y) / maxf(ry, 0.1), 2.0)
				if d > 1.0:
					continue
				if d > 0.86:
					_dpx(x, y, WH if h >= 0.0 and h < 0.06 else CY[3], 0.8 * fl)
				elif y % 4 == 0 and (x + ((y / 4) % 2) * 2) % 4 == 0:
					_dpx(x, y, CY[2], 0.45 * fl)
		if h >= 0.0:
			# Fêlures depuis le point d'impact, côté Ancre.
			var side := 1.0 if Overload.ring_center().x >= _eng.x else -1.0
			var hit := c + Vector2(side * (rx - 1.0), -3.0)
			for k in 6:
				var ang := (PI if side > 0.0 else 0.0) + (_h(k, 1, 2) - 0.5) * 2.4
				var len := clampf(h / 0.3, 0.0, 1.0) * (10.0 + _h(k, 2, 2) * 12.0)
				_bolt(hit, hit + Vector2(cos(ang) * len, sin(ang) * len * 1.3), k * 19 + 3, WH, CY[3], 1.5)
	if h >= 0.0 and h < 0.08:
		var side2 := 1.0 if Overload.ring_center().x >= _eng.x else -1.0
		_disc(_eng.x + side2 * 8.0, _eng.y - 22.0, 5.0, PUR[6], 1.0 - h / 0.08)
	if h >= Overload.BLAST:
		_burst(51, 40, h - Overload.BLAST, c, -PI, PI, 30.0, 80.0, 0.3, 0.8, 160.0, _eng.y, [WH, CY[4], CY[3]])


func _blast(h: float) -> void:
	var k := h - Overload.BLAST
	if k < 0.0 or k > 3.0:
		return
	var c := _eng + Vector2(1.0, -20.0)
	if k < 0.12:
		_disc(c.x, c.y, 4.0 + 10.0 * (1.0 - k / 0.12), WH, 1.0)
		var r := 6.0 + k * 110.0
		_ring(c, r, r, CY[3], 1.0 - k / 0.12)
	_smoke(k, c + Vector2(2.0, 4.0), 14, 12, 0.02, 1.3, 13.0, 5.0, 10.0, 1.0, 1.0, SMK)
	# Poussière d'ardoise quand le genou touche le sol.
	_smoke(h - Overload.LAND - Overload.FALL, _eng + Vector2(-6.0, 0.0), 17, 5, 0.0, 0.8, 8.0, 1.5, 4.0, 0.6, 0.3, DUST)


## Pièces d'armure : en vol (air = vrai) ou posées au sol, où elles restent.
func _debris_draw(h: float, air: bool) -> void:
	var a0 := h - Overload.BLAST
	if a0 < 0.0 or is_nan(a0):
		return
	for d in _debris:
		var a: float = a0 - d["dl"]
		if a < 0.0:
			continue
		var q := _deb_pos(d, a)
		if q[2] != air:
			continue
		var rows: Array = d["rots"][(floori(a * 16.0) + int(d["spin"])) % 4 if air else int(d["rest"])]
		var hh := rows.size()
		var ww: int = (rows[0] as String).length()
		var x0 := _jr(q[0] - ww / 2.0)
		var y0 := _jr(q[1] - hh + 1.0)
		for y in hh:
			for x in ww:
				if (rows[y] as String)[x] == ".":
					continue
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var xx := x + o.x
					var yy := y + o.y
					if yy < 0 or yy >= hh or xx < 0 or xx >= ww or (rows[yy] as String)[xx] == ".":
						_npx(x0 + xx, y0 + yy, OUTC)
		for y in hh:
			for x in ww:
				var ch := (rows[y] as String)[x]
				if ch != ".":
					_npx(x0 + x, y0 + y, DPAL[ch])


static func _deb_pos(d: Dictionary, a: float) -> Array:
	var vy: float = d["vy"]
	var y0: float = d["y0"]
	var gy: float = d["gy"]
	var tl := (-vy + sqrt(vy * vy + 2.0 * GRAVITY * maxf(0.0, gy - y0))) / GRAVITY
	if a < tl:
		return [d["x0"] + d["vx"] * a, y0 + vy * a + 0.5 * GRAVITY * a * a, true]
	var b := a - tl
	var hb := 0.2
	var xl: float = d["x0"] + d["vx"] * tl
	if b < hb:
		return [xl + d["vx"] * 0.3 * b, gy - sin(PI * b / hb) * minf(4.0, absf(vy + GRAVITY * tl) * 0.03), true]
	return [xl + d["vx"] * 0.3 * hb, gy, false]
