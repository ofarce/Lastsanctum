class_name EffectsDrawer
extends RefCounted
## Effets de combat dessinés à la résolution de l'écran (drawEffects, drawFireWalls, drawTurretBolts,
## Index.html, adepts.js, turret-game.js, 73b410f) : rivet de l'Ingénieur, flèche de l'archer, carreaux et
## explosions du Tireur (pixels natifs, npx), impacts (sphère dégradée), rayons, zones, murs de feu,
## carreaux des balistes. Les tirages (rng(seed)) reproduisent ceux du prototype.

const ItemIcon := preload("res://ui/inventory/item_icon.gd")

const RIVET_GLOW: Array[Color] = [Color("#4a2206"), Color("#8a420c"), Color("#d0781a"), Color("#ffb03c"), Color("#ffe08a")]
const RIVET_BRASS := Color("#f0cc6a")
const RIVET_DARK := Color("#6a4a14")
const ARROW_SHAFT := Color("#6c4c2e")
const ARROW_HEAD := Color("#d6d9dc")
const ARROW_TIP := Color("#bcdcff")
const ARROW_FL := Color("#ac3438")
const ARROW_SPARK: Array[Color] = [Color("#18448e"), Color("#2e6cc8"), Color("#64a2f4"), Color("#bcdcff")]
const FIRE: Array[Color] = [Color("#5a1408"), Color("#a82a10"), Color("#e85a18"), Color("#ff9a30"), Color("#ffd060"), Color("#fff4c0")]
const INK := Color("#0a0a0c")
## Pitons d'ancrage de l'Ingénieur (planche « Pitons d'ancrage — Suspension ») : cyan des Exilés et laiton.
const CY: Array[Color] = [Color("#0a2a33"), Color("#12596b"), Color("#1f9fb8"), Color("#5ce8ff"), Color("#c8fbff"), Color("#ffffff")]
const BRASS: Array[Color] = [Color("#3a2808"), Color("#6a4a14"), Color("#a07424"), Color("#d0a03c"), Color("#f0cc6a"), Color("#fff0b0")]
## Tramage ordonné 4 × 4 (BAYER, decor.js).
const BAYER := [[0.5 / 16, 8.5 / 16, 2.5 / 16, 10.5 / 16], [12.5 / 16, 4.5 / 16, 14.5 / 16, 6.5 / 16],
	[3.5 / 16, 11.5 / 16, 1.5 / 16, 9.5 / 16], [15.5 / 16, 7.5 / 16, 13.5 / 16, 5.5 / 16]]

var ci: CanvasItem
var world: World
var px := 1.0
## Préchauffage (étape 12) : pendant les premières images, un exemplaire de chaque effet est dessiné hors
## de l'écran avec le vrai code de dessin, pour que les shaders soient compilés au chargement et non au
## premier tir (jusqu'à 300 ms d'arrêt mesurés au premier rivet). L'état de la partie n'est pas touché.
var warmup_frames := 2


static func jr(v: float) -> float:
	return floorf(v + 0.5)


## natP : position native à l'écran, arrondie.
func nat_p(x: float, z: float) -> Vector2:
	var n := Proj.nat(x, 0.0, z) + world.native_offset
	return Vector2(jr(n.x), jr(n.y))


## npx : un pixel natif (PX × PX pixels d'écran).
func npx(x: float, y: float, c: Color) -> void:
	ci.draw_rect(Rect2(jr(x) * px, jr(y) * px, px, px), c)


func draw_all(now: float) -> void:
	px = float(world.camera.px)
	if warmup_frames > 0:
		warmup_frames -= 1
		_warmup()
	for drop: Dictionary in GameState.ground_items:
		var position: Vector2 = drop["position"]
		var screen := nat_p(position.x, position.y) * px
		ci.draw_circle(screen + Vector2(0, 3 * px), 7 * px, Color("#00000066"))
		ItemIcon.draw_item(ci, drop["item"], screen, px)
	_fire_walls(now)
	for e in GameState.effects:
		match e["type"]:
			"rivet": _rivet(e)
			"rivethit": _rivet_hit(e)
			"arrow": _arrow(e)
			"arrowhit": _arrow_hit(e)
			"xbolt": _xbolt(e)
			"xboom": _xboom(e)
			"piton": _piton_flight(e)
			"suspend": _suspend(e, now)
			_: _simple(e)
	_planted_pitons(now)
	_turret_bolts()


func _z() -> float:
	return 8.0 * px / 0.86


# ---------------------------------------------------------------- Rivet

func _rivet_path(e: Dictionary, p: float) -> Vector2:
	var s := nat_p(e["x"], e["z"])
	var t := nat_p(e["tx"], e["tz"])
	var a := Vector2(s.x + e["face"] * 10.0, s.y - 22.0)
	var b := Vector2(t.x, t.y - 14.0)
	return a + (b - a) * p


func _rivet(e: Dictionary) -> void:
	var p := minf(1.0, e["age"] / e["duration"])
	var q := _rivet_path(e, p)
	var q0 := _rivet_path(e, maxf(0.0, p - 0.05))
	var l := q.distance_to(q0)
	if l == 0.0:
		l = 1.0
	var ux := (q.x - q0.x) / l
	var uy := (q.y - q0.y) / l
	var R := Rng.new(e["seed"])
	for i in range(1, 11):
		if R.next() < 1.0 - i / 11.0:
			npx(q.x - ux * i * 1.6, q.y - uy * i * 1.6, RIVET_GLOW[maxi(1, 4 - (i >> 1))])
	for i in range(-1, 5):
		npx(q.x - ux * i + uy, q.y - uy * i - ux, INK)
		npx(q.x - ux * i - uy * 2.0, q.y - uy * i + ux * 2.0, INK)
	for i in 4:
		npx(q.x - ux * i, q.y - uy * i, Color("#fff0b0") if i < 1 else RIVET_BRASS)
		npx(q.x - ux * i - uy, q.y - uy * i + ux, RIVET_DARK)
	npx(q.x + ux, q.y + uy, Color.WHITE)


func _rivet_hit(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p: float = e["age"] / e["duration"]
	var o: Variant = e["tgt"] if e["tgt"] and e["tgt"].hp > 0.0 else null
	var at := nat_p(o.x, o.z) if o else nat_p(e["x"], e["z"])
	var cy := at.y - 14.0
	var face: float = e["face"]
	var hx := at.x - face * 3.0
	var R := Rng.new(e["seed"])
	if p < 0.25:
		var q := p / 0.25
		for k in 8:
			var a := k / 8.0 * 6.283 + R.next() * 0.5
			var d := 1.0 + q * 6.0
			if R.next() > q * 0.7:
				npx(hx + cos(a) * d, cy + sin(a) * d * 0.7, RIVET_GLOW[4 if q < 0.5 else 3])
	var c := Color("#fff0b0") if p < 0.3 else (RIVET_GLOW[3] if p < 0.6 else (RIVET_GLOW[2] if p < 0.85 else RIVET_GLOW[1]))
	npx(hx, cy, c)
	npx(hx - face, cy, c)
	npx(hx - face * 2.0, cy, RIVET_DARK)


# ---------------------------------------------------------------- Flèche

func _arrow_path(e: Dictionary, p: float) -> Vector2:
	var s := nat_p(e["x"], e["z"])
	var t := nat_p(e["tx"], e["tz"])
	var x0: float = s.x + e["face"] * 12.0
	var y0 := s.y - 24.0
	var x1 := t.x
	var y1 := t.y - 14.0
	var h := 1.0 + Vector2(x1 - x0, y1 - y0).length() * 0.025
	return Vector2(x0 + (x1 - x0) * p, y0 + (y1 - y0) * p - h * 4.0 * p * (1.0 - p))


func _arrow(e: Dictionary) -> void:
	var p := minf(1.0, e["age"] / e["duration"])
	var q := _arrow_path(e, p)
	var q0 := _arrow_path(e, maxf(0.0, p - 0.06))
	var l := q.distance_to(q0)
	if l == 0.0:
		l = 1.0
	var ux := (q.x - q0.x) / l
	var uy := (q.y - q0.y) / l
	var R := Rng.new(e["seed"])
	for i in range(1, 10):
		var qq := p - i * 0.03
		if qq < 0.0:
			break
		var s := _arrow_path(e, qq)
		for k in 3:
			if R.next() < 1.0 - i / 10.0:
				var ox := (R.next() - 0.5) * 3.0
				var oy := (R.next() - 0.5) * 3.0
				npx(s.x + ox, s.y + oy, ARROW_SPARK[maxi(0, 3 - (i >> 1) - (k >> 1))])
	for i in range(-1, 12):
		npx(q.x - ux * i + uy, q.y - uy * i - ux, INK)
		npx(q.x - ux * i - uy * 2.0, q.y - uy * i + ux * 2.0, INK)
	for i in 11:
		npx(q.x - ux * i, q.y - uy * i, ARROW_HEAD if i < 3 else ARROW_SHAFT)
		npx(q.x - ux * i - uy, q.y - uy * i + ux, Color("#a2a6ab") if i < 3 else Color("#3e2a18"))
	npx(q.x + ux, q.y + uy, ARROW_TIP)
	npx(q.x + ux * 2.0, q.y + uy * 2.0, Color.WHITE)
	for sg in [-1.0, 1.0]:
		npx(q.x - ux - uy * sg * 1.5, q.y - uy + ux * sg * 1.5, ARROW_HEAD)
	for sg in [-1.0, 1.0]:
		for i in range(8, 12):
			npx(q.x - ux * i - uy * sg * 2.0, q.y - uy * i + ux * sg * 2.0, ARROW_FL)


func _arrow_hit(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p: float = e["age"] / e["duration"]
	var at := nat_p(e["x"], e["z"])
	var cy := at.y - 14.0
	var r := 1.0 + p * 6.0
	var R := Rng.new(e["seed"])
	for k in 10:
		var a := k / 10.0 * 6.283 + R.next() * 0.4
		var d := r * (0.6 + R.next() * 0.5)
		if R.next() > p * 0.8:
			npx(at.x + cos(a) * d, cy + sin(a) * d * 0.7, ARROW_SPARK[3 if p < 0.4 else 2 - (k & 1)])
	if p < 0.35:
		npx(at.x, cy, Color.WHITE)
		npx(at.x + 1.0, cy, ARROW_SPARK[3])
		npx(at.x - 1.0, cy, ARROW_SPARK[3])
		npx(at.x, cy - 1.0, ARROW_SPARK[3])
		npx(at.x, cy + 1.0, ARROW_SPARK[3])


# ---------------------------------------------------------------- Carreaux et explosions du Tireur

func _xbolt(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p := minf(1.0, e["age"] / e["duration"])
	var s := nat_p(e["x"], e["z"])
	var t := nat_p(e["tx"], e["tz"])
	var x0: float = s.x + e["face"] * 14.0
	var y0 := s.y - 22.0
	var x := x0 + (t.x - x0) * p
	var y := y0 + (t.y - 14.0 - y0) * p
	var l := Vector2(t.x - x0, t.y - 14.0 - y0).length()
	if l == 0.0:
		l = 1.0
	var ux := (t.x - x0) / l
	var uy := (t.y - 14.0 - y0) / l
	for i in 14:
		if BAYER[(int(jr(y)) + i) & 3][i & 3] < 1.0 - i / 14.0:
			npx(x - ux * (i + 6), y - uy * (i + 6), Color("#ffe08a") if i < 5 else Color("#d0781a"))
	for i in range(-1, 8):
		npx(x - ux * i + uy, y - uy * i - ux, INK)
		npx(x - ux * i - uy, y - uy * i + ux, INK)
	for i in 7:
		npx(x - ux * i, y - uy * i, Color("#d6d9dc") if i < 2 else Color("#4e4e56"))
	npx(x + ux, y + uy, Color("#ffb03c"))
	npx(x + ux * 2.0, y + uy * 2.0, Color("#fff0a0"))


func _xboom(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var p: float = e["age"] / e["duration"]
	var at := nat_p(e["x"], e["z"])
	var x := at.x
	var cy := at.y - 10.0
	var r := 2.0 + sqrt(p) * 9.0
	var R := Rng.new(e["seed"])
	var j := -r
	while j <= r:
		var i := -r
		while i <= r:
			var d := Vector2(i, j * 1.2).length() / r
			if d <= 1.0 and not (p > 0.5 and BAYER[floori(cy + j) & 3][floori(x + i) & 3] < (p - 0.5) * 2.0):
				var h := (1.0 - p) * (1.0 - d * 0.7)
				var c := Color.WHITE if h > 0.7 else (Color("#ffe08a") if h > 0.5 else (Color("#ffb03c") if h > 0.32 else
					(Color("#d0781a") if h > 0.16 else (Color("#4a4440") if p > 0.55 else Color("#8a222c")))))
				npx(x + i, cy + j, c)
			i += 1.0
		j += 1.0
	for k in 12:
		var a := R.next() * 6.283
		var d := r * (1.1 + p) * (0.7 + R.next() * 0.5)
		if p < 0.75:
			npx(x + cos(a) * d, cy + sin(a) * d * 0.8, Color("#ffe08a") if p < 0.35 else Color("#d0781a"))


# ---------------------------------------------------------------- Rayons, impacts, zones

func _simple(e: Dictionary) -> void:
	var a: float = 1.0 - e["age"] / e["duration"]
	var cam := world.camera
	var col: Color = e["color"]
	match e["type"]:
		"laser":
			ci.draw_line(cam.project(e["x"], 1.35, e["z"]), cam.project(e["tx"], 1.2, e["tz"]), Color(col, col.a * a), 3.0, true)
		"hit":
			# sphere3 : disque à dégradé radial (#f2f3eb, couleur à 15 %, #090c14), centre décalé vers le haut à gauche.
			var c := cam.project(e["x"], 1.4, e["z"])
			var sz := 0.4 * a * _z()
			if sz < 0.5:
				return
			var steps := 10
			for k in range(steps, 0, -1):
				var t := float(k) / steps
				var focus := c + Vector2(-0.3, -0.35) * sz * (1.0 - t)
				var cc := Color("#f2f3eb").lerp(col, clampf(t / 0.15, 0.0, 1.0)) if t < 0.15 else col.lerp(Color("#090c14"), (t - 0.15) / 0.85)
				ci.draw_circle(focus, sz * t, Color(cc, a))
		"zone":
			var c := cam.project(e["x"], 0.0, e["z"])
			var pts := PackedVector2Array()
			for k in 49:
				var ang := TAU * k / 48.0
				pts.append(c + Vector2(cos(ang) * e["r"] * _z() * 0.85, sin(ang) * e["r"] * _z() * 0.4))
			ci.draw_polyline(pts, Color(col, col.a * a), 3.0, true)


# ---------------------------------------------------------------- Murs de feu, carreaux des balistes

func _fire_walls(now: float) -> void:
	var cam := world.camera
	var z := _z()
	var s := maxf(2.0, z * 0.12)
	for w in GameState.fire_walls:
		var age: float = now - w["t0"]
		var head: float = minf(1.0, age / 0.4) * w["len"]
		var fade := minf(1.0, (w["until"] - now) / 0.5)
		var d := 0.0
		while d < head:
			var p := cam.project(w["x"] + w["dx"] * d, 0.0, w["z"] + w["dz"] * d)
			var fl := sin(now * 23.0 + d * 7.0) * 0.5 + 0.5
			var hgt := (1.6 if head - d < 1.0 else 0.9) * fade
			for k in 3:
				var y := p.y - (k * 0.35 + fl * 0.3) * hgt * z
				var ci_ := clampi(int(jr(5.0 - k * 1.5 - fl - (1.0 - fade) * 3.0)), 0, 5)
				ci.draw_rect(Rect2(p.x - s / 2.0 + sin(d * 13.0 + k) * s, y, s, s), FIRE[ci_])
			d += 0.22


func _turret_bolts() -> void:
	var cam := world.camera
	for b in GameState.turret_bolts:
		var t := minf(1.0, b["age"] / b["duration"])
		var tg: Enemy = b["target"]
		var target := Vector2(tg.x, tg.z) if tg.hp > 0.0 else Vector2(b["tx"], b["tz"])
		var p := cam.project(b["x"], 6.5, b["z"])
		var q := cam.project(target.x, 1.3, target.y)
		var dv := q - p
		var length := dv.length()
		if length == 0.0:
			length = 1.0
		var u := dv / length
		var at := p + dv * t
		ci.draw_line(at - u * 16.0, at, Color("#dec79b"), maxf(2.0, _z() * 0.09), true)
		ci.draw_colored_polygon(PackedVector2Array([at + u * 5.0, at - u * 3.0 + Vector2(u.y, -u.x) * 3.0, at - u * 3.0 - Vector2(u.y, -u.x) * 3.0]), Color("#c8d0c5"))


## Un effet de chaque type, à mi-course, loin hors de l'écran (x = 5000 unités).
func _warmup() -> void:
	var x := 5000.0
	var z := 0.0
	var c := Color("#f0dba4")
	for e: Dictionary in [
		{"type": "hit", "x": x, "z": z, "age": 0.05, "duration": 0.22, "color": c},
		{"type": "zone", "x": x, "z": z, "r": 2.0, "age": 0.3, "duration": 1.0, "color": c},
		{"type": "laser", "x": x, "z": z, "tx": x + 6.0, "tz": z, "age": 0.03, "duration": 0.13, "color": c},
		{"type": "rivet", "x": x, "z": z, "tx": x + 8.0, "tz": z, "face": 1, "age": 0.05, "duration": 0.12, "seed": 1},
		{"type": "rivethit", "x": x, "z": z, "face": 1, "tgt": null, "age": 0.1, "duration": 1.0, "seed": 1},
		{"type": "arrow", "x": x, "z": z, "tx": x + 8.0, "tz": z, "face": 1, "age": 0.08, "duration": 0.16, "seed": 1},
		{"type": "arrowhit", "x": x, "z": z, "age": 0.08, "duration": 0.24, "seed": 1},
		{"type": "xbolt", "x": x, "z": z, "tx": x + 8.0, "tz": z, "face": 1, "age": 0.05, "duration": 0.11, "seed": 1},
		{"type": "xboom", "x": x, "z": z, "age": 0.15, "duration": 0.45, "seed": 1}]:
		match e["type"]:
			"rivet": _rivet(e)
			"rivethit": _rivet_hit(e)
			"arrow": _arrow(e)
			"arrowhit": _arrow_hit(e)
			"xbolt": _xbolt(e)
			"xboom": _xboom(e)
			_: _simple(e)


# ---------------------------------------------------------------- Pitons d'ancrage de l'Ingénieur

## Pixel natif tramé : visible si l'opacité dépasse le seuil de Bayer du pixel.
func dpx(x: float, y: float, c: Color, a: float) -> void:
	var ix := int(jr(x))
	var iy := int(jr(y))
	if BAYER[iy & 3][ix & 3] < a:
		npx(ix, iy, c)


static func _sm(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _eio(t: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0))


static func _ein(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t


static func _eout(t: float) -> float:
	t = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - t * t * t


## Ligne de pixels natifs (pleine si a ≥ 1, tramée sinon).
func nline(a: Vector2, b: Vector2, c: Color, al: float = 1.0) -> void:
	var n := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		if al >= 1.0:
			npx(p.x, p.y, c)
		else:
			dpx(p.x, p.y, c, al)


func ndisc(cx: float, cy: float, r: float, c: Color, a: float) -> void:
	for y in range(floori(cy - r), ceili(cy + r) + 1):
		for x in range(floori(cx - r), ceili(cx + r) + 1):
			if Vector2(x - cx, y - cy).length() <= r:
				dpx(x, y, c, a)


func nring(cx: float, cy: float, r: float, c: Color, a: float) -> void:
	var n := maxi(8, ceili(r * 7.0))
	for k in n:
		var t := TAU * k / n
		dpx(cx + cos(t) * r, cy + sin(t) * r * 0.75, c, a)


## Bouche du lance-pitons de l'Ingénieur u visant `target`, en pixels natifs.
func _muzzle(x: float, z: float, target: Vector2, u: Unit) -> Vector2:
	var face := EngineerAim.face_to(x, target, u.face if u and u.face != 0 else 1)
	return nat_p(x, z) + EngineerAim.muzzle(EngineerAim.angle_to(x, z, target, face), face)


## Piton planté : halo cyan pulsé, tête de laiton cernée.
func _pin(p: Vector2, k: int, now: float) -> void:
	var gl := 0.55 + 0.45 * sin(now * 8.0 + k * 1.7)
	ndisc(p.x + 0.5, p.y + 0.5, 2.6, CY[1], 0.45 * gl)
	for o: Vector2 in [Vector2(-1, 0), Vector2(2, 0), Vector2(0, -1), Vector2(1, -1), Vector2(0, 2), Vector2(1, 2), Vector2(-1, 1), Vector2(2, 1)]:
		npx(p.x + o.x, p.y + o.y, INK)
	npx(p.x, p.y, BRASS[5])
	npx(p.x + 1, p.y, BRASS[3])
	npx(p.x, p.y + 1, BRASS[3])
	npx(p.x + 1, p.y + 1, BRASS[1])
	dpx(p.x, p.y, CY[4], gl * 0.6)


func _piton_flight(e: Dictionary) -> void:
	if e["age"] < 0.0:
		return
	var key := Vector2i(e["i"], e["j"])
	var corner := Combat.piton_corner(key, e["k"])
	var a := _muzzle(e["x"], e["z"], corner, e["unit"])
	var b := nat_p(corner.x, corner.y)
	var p := minf(1.0, e["age"] / e["duration"])
	var dd := (b - a).normalized()
	var pos := a.lerp(b, p) - Vector2(0, sin(PI * p) * 2.0)
	if p < 0.6:
		ndisc(a.x, a.y, 2.2, CY[4], 1.0 - p / 0.6)
		npx(a.x, a.y, Color.WHITE)
	for j in range(1, 9):
		dpx(pos.x - dd.x * j, pos.y - dd.y * j, CY[4] if j < 3 else CY[2], 1.0 - j / 9.0)
	nline(pos - dd * 1.5, pos + dd * 1.5, BRASS[4])
	npx(pos.x + dd.x * 2.0, pos.y + dd.y * 2.0, Color.WHITE)


## Pitons fichés dans les cases en cours de creusement (coups déjà portés), avec l'onde d'impact.
func _planted_pitons(now: float) -> void:
	var st := world.terrain_state
	for key: Vector2i in st.dig_hits:
		var h: int = st.dig_hits[key]
		var since: float = now - float(st.dig_hit_at.get(key, -100.0)) - Combat.PITON_FLIGHT
		for k in mini(h, 4):
			if k == h - 1 and since < 0.0:
				continue
			var c := Combat.piton_corner(key, k)
			var p := nat_p(c.x, c.y)
			if k == h - 1 and since < 0.3:
				var q := since / 0.3
				nring(p.x, p.y, 0.8 + _eout(q) * 5.0, CY[3], 1.0 - q)
				for m in 5:
					var R := Rng.new(key.x * 131 + key.y * 17 + k * 7 + m)
					var ang := -PI * (0.1 + R.next() * 0.8)
					var sp := 10.0 + R.next() * 18.0
					npx(p.x + cos(ang) * sp * since, p.y + sin(ang) * sp * since + 60.0 * since * since, Color("#6b6250") if m & 1 else Color("#a89c86"))
			_pin(p, k, now)


## Suspension de la case : cadre cyan entre les pitons, cubes de roche figés en l'air avec la poussière
## arrêtée, compression en un point lumineux, éclair, retour des pitons au poignet de l'Ingénieur.
func _suspend(e: Dictionary, now: float) -> void:
	if e["age"] < 0.0:
		return
	var q: float = e["age"] / e["duration"]
	var key := Vector2i(e["i"], e["j"])
	var o := nat_p(key.x * 4.0, key.y * 4.0)
	var cc := o + Vector2(15.5, 15.5)
	var T: Array[Vector2] = []
	for k in 4:
		var c := Combat.piton_corner(key, k)
		T.append(nat_p(c.x, c.y))
	var img: Image = e["img"]
	# Roche de la case : intacte et teintée de cyan, puis fendue en cubes de 8 px, puis comprimée.
	if img and q < 0.8:
		var e1 := _eio((q - 0.12) / 0.33)
		var e2 := _ein((q - 0.45) / 0.35)
		for ly in 32:
			for lx in 32:
				var col := img.get_pixel(lx, ly)
				if col.a < 0.5:
					continue
				var tint: bool = BAYER[ly & 3][lx & 3] < 0.28 * _sm(q / 0.12)
				if q < 0.12:
					npx(o.x + lx, o.y + ly, CY[2] if tint else col)
					continue
				var pc := Vector2(floorf(lx / 8.0) * 8.0 + 4.0, floorf(ly / 8.0) * 8.0 + 4.0)
				var off := (pc - Vector2(15.5, 15.5)) * 0.25 * e1 - Vector2(0, 3.0 * e1)
				var rim: bool = (lx % 8 == 7 or ly % 8 == 7) and BAYER[ly & 3][lx & 3] < 0.6
				var cr := CY[2] if rim and e1 > 0.1 else col
				if q < 0.45:
					npx(o.x + lx + off.x, o.y + ly + off.y, cr)
				else:
					var s := 1.0 - e2
					var pp := cc + (Vector2(lx, ly) + off - Vector2(15.5, 15.5)) * s
					npx(pp.x, pp.y, CY[5] if e2 > 0.8 else (CY[4] if e2 > 0.5 else (CY[3] if e2 > 0.2 else cr)))
	# Cadre cyan entre les pitons, puis filins vers le centre pendant la compression.
	if q < 0.45:
		var w := _sm(q / 0.12) * 4.0
		for k in 4:
			var f := clampf(w - k, 0.0, 1.0)
			if f <= 0.0:
				break
			var flick := Rng.new(k * 97 + int(now * 20.0)).next() > 0.8
			nline(T[k], T[k].lerp(T[(k + 1) % 4], f), CY[4] if flick else CY[3], 1.0 if q < 0.12 else 0.8)
	elif q < 0.8:
		var e2 := _ein((q - 0.45) / 0.35)
		for k in 4:
			nline(T[k], T[k].lerp(cc, e2), CY[3], 0.7)
	# Éclair final.
	if q > 0.8 and q < 0.92:
		var f := (q - 0.8) / 0.12
		nring(cc.x, cc.y, 2.0 + f * 9.0, CY[4], 1.0 - f)
		for r in int(6.0 * (1.0 - f)) + 1:
			for d: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
				npx(cc.x + d.x, cc.y + d.y, Color.WHITE)
	# Poussière figée en l'air, qui retombe après l'éclair.
	if q > 0.12:
		for j in 16:
			var R := Rng.new(j * 29 + 3)
			var x := o.x - 4.0 + R.next() * 40.0
			var y := o.y - 6.0 + R.next() * 40.0
			var c := Color("#6b6250") if R.next() < 0.5 else Color("#c9b98f")
			if q > 0.8:
				var t: float = (q - 0.8) * e["duration"]
				y += 100.0 * t * t
				if y > o.y + 36.0:
					continue
			dpx(x, y, c, (q - 0.12) / 0.08 if q < 0.2 else 1.0)
	# Pitons : fichés aux angles, puis rappelés vers le lance-pitons.
	var u: Unit = e["unit"]
	for k in 4:
		var p := T[k]
		if q > 0.85:
			if q > 0.98:
				continue
			var hand := _muzzle(u.x, u.z, Vector2(e["x"], e["z"]), u) if u else cc
			p = T[k].lerp(hand, _ein((q - 0.85) / 0.15))
		_pin(p, k, now)
