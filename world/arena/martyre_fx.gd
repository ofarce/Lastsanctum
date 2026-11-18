class_name MartyreFx
extends RefCounted
## Rendu des attaques à distance de la Martyre de Byrsa (GameState.martyre_fx, sim/martyre.gd), d'après
## planches/martyre-v3-propositions.html :
## - fissure 4.1 « Faille en relief » : une tranchée qui s'ouvre derrière une pointe éclatante, lèvre de pierre
##   claire, paroi du fond dans l'ombre, lit en fusion en dégradé de chaleur (carmin sur les bords, blanc au
##   centre) qui coule ; au bout, une colonne de lumière et des pierres projetées, puis la faille refroidit ;
## - sceaux 5.3 « Rai du ciel » : cercle d'or gravé qui se remplit, fil de lumière tremblant venu du ciel,
##   puis colonne évasée et sol qui brûle.
## Appelé par MartyreDome : ground() sous les sprites, air() par-dessus. Repère : pixels natifs du monde.

const HEAT := [Color("#1a0204"), Color("#3e080c"), Color("#6e1014"), Color("#a41a1a"), Color("#d63a22"),
	Color("#f26a2a"), Color("#ffa846"), Color("#ffdc8c"), Color("#fff6dc")]
const LIGHT := [Color("#3a280c"), Color("#6a4a16"), Color("#a07424"), Color("#d0a038"), Color("#f0cc66"),
	Color("#fff2b0"), Color("#fffbe8")]
const STONE := [Color("#140e0a"), Color("#211812"), Color("#30241a"), Color("#423224"), Color("#55432f"), Color("#6a563c")]
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const GLYPHS := [[".#.", "###", ".#.", "#.#"], ["##.", ".#.", ".##", ".#."], ["#.#", ".#.", "#.#", "###"],
	["###", "#..", "##.", "#.."], [".#.", "#.#", ".#.", ".#."], ["#..", "###", "..#", ".##"]]
## Demi-largeur maximale de la faille, hauteur du ciel au-dessus d'un sceau (pixels natifs).
const FISSURE_W := 3.2
const SKY := 260.0


static func _bay(p: Vector2) -> float:
	return (BAYER[posmod(int(p.y), 4)][posmod(int(p.x), 4)] + 0.5) / 16.0


## Couleur tramée d'une rampe pour v ∈ [0, 1] au pixel p.
static func ramp(r: Array, v: float, p: Vector2) -> Color:
	var f := clampf(v, 0.0, 1.0) * (r.size() - 1)
	var i := floori(f)
	return r[mini(r.size() - 1, i + 1 if f - i > _bay(p) else i)]


static func _px(ci: CanvasItem, p: Vector2, c: Color, a := 1.0) -> void:
	ci.draw_rect(Rect2(p.round(), Vector2.ONE), Color(c, c.a * a))


static func _h(a: int, b: int) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)


# ---------------------------------------------------------------- Couches

static func ground(ci: CanvasItem) -> void:
	var now := GameState.sim_time
	for f: Dictionary in GameState.martyre_fx:
		if f["type"] == "fissure":
			_trench(ci, f, now)
		else:
			_seal_ground(ci, f, now)


static func air(ci: CanvasItem) -> void:
	var now := GameState.sim_time
	for f: Dictionary in GameState.martyre_fx:
		if f["type"] == "fissure":
			_eruption(ci, f, now)
		else:
			_seal_sky(ci, f, now)
	# Étoiles d'étourdissement au-dessus de l'Ingénieur.
	for u: Unit in GameState.units:
		if u.stunned_until > now and u.alive():
			var c := Proj.nat(u.x, 0.0, u.z) + Vector2(0.0, -44.0)
			for k in 3:
				var g := now * 7.0 + k * TAU / 3.0
				_px(ci, c + Vector2(cos(g) * 6.0, sin(g) * 2.0), LIGHT[5])
				_px(ci, c + Vector2(cos(g) * 6.0 + 1.0, sin(g) * 2.0), LIGHT[4])


# ---------------------------------------------------------------- Fissure

## Points du tracé (pixels natifs), une fois par fissure : sinuosité douce autour de la droite.
static func _path(f: Dictionary) -> Dictionary:
	if f.has("_path"):
		return f["_path"]
	var p0 := Proj.nat(f["x0"], 0.0, f["z0"])
	var p1 := Proj.nat(f["x1"], 0.0, f["z1"])
	var d := (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	if n.y > 0.0:
		n = -n
	var count := maxi(2, ceili(p0.distance_to(p1)))
	var s: float = f["seed"]
	var pts := PackedVector2Array()
	for i in count:
		var j := 2.2 * sin(i * 0.09 + s) + 1.1 * sin(i * 0.23 + s * 1.7)
		pts.append(p0 + d * i + n * j)
	var out := {"pts": pts, "n": n, "end": p1}
	f["_path"] = out
	return out


static func _width(i: int, count: int) -> float:
	return maxf(0.6, FISSURE_W * pow(sin(PI * clampf((i + 2.0) / (count + 4.0), 0.0, 1.0)), 0.5))


static func _trench(ci: CanvasItem, f: Dictionary, now: float) -> void:
	var P := _path(f)
	var pts: PackedVector2Array = P["pts"]
	var n: Vector2 = P["n"]
	var count := pts.size()
	var F: Dictionary = Martyre.FISSURE
	var u := clampf((now - f["at"]) / maxf(0.01, f["erupt"] - f["at"]), 0.0, 1.0)
	var cool := clampf((now - f["erupt"] - F["erupt"]) / F["cool"], 0.0, 1.0)
	var shown := floori(u * count)
	# Halo au sol.
	for i in range(0, shown, 4):
		ci.draw_circle(pts[i], _width(i, count) + 5.0, Color(HEAT[3], 0.12 * (1.0 - cool)))
	for i in shown:
		var p := pts[i]
		var hw := _width(i, count) * clampf((shown - i) / 14.0, 0.0, 1.0)
		var flow := 0.1 * sin(i * 0.35 - now * 9.0)
		var depth := maxf(1.0, roundf(hw * 0.9))
		var top := -roundf(hw)
		var bot := roundf(hw)
		_px(ci, p + n * (top - 1.0), STONE[4])
		if i % 3:
			_px(ci, p + n * (top - 2.0), STONE[5], 0.5)
		var k := top
		while k <= bot:
			var q := p + n * k
			if k < top + depth and k < bot:
				_px(ci, q, ramp(STONE, 0.15 + (k - top) / depth * 0.25, q))
			else:
				var mid := (top + depth + bot) / 2.0
				var c := 1.0 - absf(k - mid) / maxf(1.0, (bot - top - depth) / 2.0 + 0.5)
				_px(ci, q, ramp(HEAT, (0.45 + 0.5 * c + flow) * (1.0 - cool * 0.7), q))
			k += 1.0
		_px(ci, p + n * (bot + 1.0), STONE[1])
	# Pointe éclatante tant que la faille court.
	if u < 1.0 and shown > 0:
		var tip := pts[shown - 1]
		ci.draw_circle(tip, 5.0, Color(HEAT[4], 0.45))
		ci.draw_circle(tip, 2.6, Color(HEAT[6], 0.85))
		_px(ci, tip, HEAT[8])
	# Braises.
	for j in 18:
		if shown == 0:
			break
		var per := 0.8 + _h(j, 1)
		var ph := fposmod(now + _h(j, 2) * per, per) / per
		var p := pts[floori(_h(j, 3) * shown)]
		_px(ci, p + Vector2(sin(ph * 6.0 + j) * 1.5, -ph * 14.0), HEAT[7 if ph < 0.5 else 5], (1.0 - ph) * (1.0 - cool))


static func _eruption(ci: CanvasItem, f: Dictionary, now: float) -> void:
	var F: Dictionary = Martyre.FISSURE
	var e: float = (now - float(f["erupt"])) / float(F["erupt"])
	if e < 0.0 or e >= 1.0:
		return
	var c: Vector2 = _path(f)["end"]
	var w: float = 7.0 * (1.0 - e * 0.6)
	var h: float = lerpf(70.0, 90.0, e) * (e / 0.12 if e < 0.12 else 1.0)
	# Colonne en dégradé : bandes verticales, plus pâles au centre, qui s'éteignent vers le haut.
	var x: float = -w
	while x <= w:
		var cc: float = 1.0 - absf(x) / w
		for s in 4:
			var y0: float = h * s / 4.0
			_band(ci, c + Vector2(x, -y0 - h / 4.0), h / 4.0, ramp(HEAT, 0.4 + 0.6 * cc - s * 0.06, c + Vector2(x, s)), (1.0 - e) * (1.0 - s * 0.22))
		x += 1.0
	ci.draw_arc(c, 4.0 + e * 22.0, 0.0, TAU, 32, Color(HEAT[6], 1.0 - e), 1.0)
	for j in 9:
		var g := -PI * (0.1 + 0.8 * _h(j, 7))
		var v := 20.0 + _h(j, 8) * 30.0
		var p := c + Vector2(cos(g) * v * e, sin(g) * v * e * 1.4 + e * e * 55.0)
		if p.y > c.y + 2.0:
			continue
		ci.draw_rect(Rect2(p.round() - Vector2(2, 1), Vector2(4, 3)), STONE[3])
		_px(ci, p + Vector2(-1, -1), STONE[5])
		_px(ci, p + Vector2(0, 2), HEAT[5], 0.6)


static func _band(ci: CanvasItem, top: Vector2, height: float, c: Color, a: float) -> void:
	ci.draw_rect(Rect2(top.round(), Vector2(1.0, ceilf(height))), Color(c, a))


# ---------------------------------------------------------------- Sceaux

static func _seal_radius() -> float:
	return Martyre.SEALS["radius"] * Proj.K


static func _seal_ground(ci: CanvasItem, f: Dictionary, now: float) -> void:
	var S: Dictionary = Martyre.SEALS
	var c := Proj.nat(f["x"], 0.0, f["z"]).round()
	var r := _seal_radius()
	var i: int = f["index"]
	if now < f["boom"]:
		var fill := clampf((now - f["at"]) / S["charge"], 0.0, 1.0)
		var spin := (-1.0 if i % 2 else 1.0) * now * 0.8
		for k in 72:
			var g := k / 72.0 * TAU + spin
			_px(ci, c + Vector2(cos(g), sin(g)) * r, LIGHT[4] if k % 9 < 6 else LIGHT[2])
			if k % 2:
				_px(ci, c + Vector2(cos(g), sin(g)) * (r - 2.0), LIGHT[3], 0.8)
		for k in 6:
			var g := k / 6.0 * TAU - now * 0.5
			_glyph(ci, c + Vector2(cos(g), sin(g)) * r * 0.62 - Vector2(1, 2), k + i, LIGHT[4])
		# Remplissage en dégradé depuis le centre.
		var rr := r * fill
		for y in range(-ceili(rr), ceili(rr) + 1):
			for x in range(-ceili(rr), ceili(rr) + 1):
				var d := sqrt(float(x * x + y * y)) / r
				if d > fill or d >= 1.0:
					continue
				var q := c + Vector2(x, y)
				if 0.55 > _bay(q):
					_px(ci, q, ramp(LIGHT, 0.35 + 0.5 * (1.0 - absf(d - fill) * 3.0), q), 0.6)
		return
	# Sol qui brûle après l'impact.
	var b: float = (now - float(f["boom"])) / float(S["boom"])
	for y in range(-ceili(r), ceili(r) + 1):
		for x in range(-ceili(r), ceili(r) + 1):
			var d := sqrt(float(x * x + y * y)) / r
			if d >= 1.0:
				continue
			var q := c + Vector2(x, y)
			_px(ci, q, ramp(HEAT, (1.0 - d) * 0.9 * (1.0 - b * 0.5) + 0.2, q), 0.9 * (1.0 - b * 0.6))


static func _seal_sky(ci: CanvasItem, f: Dictionary, now: float) -> void:
	var S: Dictionary = Martyre.SEALS
	var c := Proj.nat(f["x"], 0.0, f["z"]).round()
	var r := _seal_radius()
	var i: int = f["index"]
	if now < f["boom"]:
		var fill := clampf((now - f["at"]) / S["charge"], 0.0, 1.0)
		if sin(now * 40.0 + i) > -0.4:
			var col: Color = LIGHT[5] if fill > 0.6 else LIGHT[3]
			var y := 0.0
			while y < SKY:
				_px(ci, c + Vector2(sin(y * 0.2 + now * 10.0) * 0.6 * (1.0 - fill), -SKY + y), col, 0.35 + 0.5 * fill)
				y += 1.0
		return
	var b: float = (now - float(f["boom"])) / float(S["boom"])
	var w: float = r * 0.7 * (b / 0.1 if b < 0.1 else 1.0) * (1.0 - b * 0.5)
	var x: float = -w
	while x <= w:
		var cc: float = 1.0 - absf(x) / w
		for s in 4:
			# De haut en bas : la colonne s'évase et s'intensifie vers le sol.
			var widen := 0.6 + 0.4 * (s + 1) / 4.0
			if absf(x) > w * widen:
				continue
			_band(ci, c + Vector2(x, -SKY + SKY * s / 4.0), SKY / 4.0, ramp(LIGHT, 0.3 + 0.7 * cc, c + Vector2(x, s)), (1.0 - b) * (0.5 + 0.5 * (s + 1) / 4.0))
		x += 1.0
	for j in 12:
		var uu := fposmod(b * 2.0 + _h(j, i + 5), 1.0)
		_px(ci, c + Vector2((_h(j, i + 9) - 0.5) * r * 1.6, -uu * 30.0), HEAT[6] if uu < 0.5 else HEAT[4], 1.0 - uu)


static func _glyph(ci: CanvasItem, at: Vector2, g: int, c: Color) -> void:
	var rows: Array = GLYPHS[g % GLYPHS.size()]
	for j in rows.size():
		var row: String = rows[j]
		for k in row.length():
			if row[k] == "#":
				_px(ci, at + Vector2(k, j), c)
