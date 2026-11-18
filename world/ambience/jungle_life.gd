class_name JungleLife
extends Node2D
## Vie de la jungle, purement décorative, dessinée autour de la caméra (pixels natifs, 1 u = 8 px) :
## oiseaux posés qui s'envolent quand quelqu'un approche, papillons, libellules au-dessus de l'eau,
## poissons qui sautent, grenouilles sur les berges, pollen, feuilles qui tombent et brume sur la rivière
## (aube et nuit). Positions tirées par cases de la carte (fonction de la case), aucun état de jeu.

const CELL := 14.0
const BIRD := [Color8(30, 24, 22), Color8(196, 64, 44), Color8(236, 210, 120)]
const BUTTERFLY := [Color8(240, 210, 80), Color8(236, 236, 226), Color8(110, 160, 230), Color8(230, 120, 60)]
const DRAGONFLY := Color8(70, 190, 180)
const FISH := Color8(190, 205, 210)
const FROG := Color8(96, 150, 60)
const POLLEN := Color8(236, 226, 150)
const LEAF := [Color8(120, 150, 60), Color8(160, 140, 60), Color8(110, 86, 44)]
const MIST := Color8(200, 214, 220)
## Distance (u) à laquelle un oiseau s'envole ; durée de l'envol ; délai avant qu'un autre se pose.
const FLEE := 5.0
const FLIGHT := 2.5
const RETURN := 25.0

var world: World
var _t := 0.0
## Case → instant de l'envol (temps propre).
var _fled := {}


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _bodies() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for u in GameState.units:
		if u.alive() and not u.hidden:
			out.append(u.pos())
	for e: Enemy in GameState.enemies:
		if e.hp > 0.0:
			out.append(e.pos())
	return out


## Pixel d'art (S pixels natifs de côté).
const S := 2.0


func _px(x: float, z: float, c: Color, w := 1.0, h := 1.0) -> void:
	draw_rect(Rect2(roundf(x * 8.0 / S) * S, roundf(z * 8.0 / S) * S, w * S, h * S), c)


func _draw() -> void:
	if world == null or world.camera == null:
		return
	var cam: Vector2 = world.camera.cam
	var half := get_viewport_rect().size / (2.0 * float(world.camera.px) * 8.0) + Vector2(4, 4)
	var night := DayNight.night(GameState.sim_time)
	var day := (1.0 - night) * (1.0 - Weather.rain())
	var river := world.terrain_state.river
	var flora := world.terrain_state.flora
	var bodies := _bodies()
	var i0 := floori((cam.x - half.x) / CELL)
	var i1 := floori((cam.x + half.x) / CELL)
	var j0 := floori((cam.y - half.y * 1.2) / CELL)
	var j1 := floori((cam.y + half.y) / CELL)
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			var cx := (i + 0.5) * CELL
			var cz := (j + 0.5) * CELL
			if cz < CaveShape.mountain_edge(cx) + 3.0:
				continue
			var h := Rng.hash3(i, j, 0xb1b1)
			var near_water := river != null and absf(river.bank_distance(cx, cz)) < CELL
			if h < 0.22 and day > 0.2:
				_bird(Vector2i(i, j), cx, cz, h, bodies, river)
			elif h < 0.30 and day > 0.4:
				_butterfly(cx, cz, h, day)
			elif h < 0.40:
				_leaf(cx, cz, h, flora)
			if near_water:
				_water_life(i, j, river, day)
			if day > 0.3:
				_pollen(cx, cz, i, j, day)
	if river:
		_mist(cam, half, river, night)


## Oiseau posé au sol ; s'envole en diagonale quand un corps approche, revient plus tard.
func _bird(key: Vector2i, cx: float, cz: float, h: float, bodies: Array[Vector2], river: River) -> void:
	var p := Vector2(cx + (Rng.hash3(key.x, key.y, 3) - 0.5) * CELL * 0.8, cz + (Rng.hash3(key.x, key.y, 4) - 0.5) * CELL * 0.8)
	if river and river.bank_distance(p.x, p.y) < 0.5:
		return
	var col: Color = BIRD[floori(h * 100.0) % BIRD.size()]
	if _fled.has(key):
		var age: float = _t - _fled[key]
		if age < FLIGHT:
			var dir := Vector2(1.0 if h > 0.08 else -1.0, -1.4)
			var q := p + dir * age * 6.0
			var flap := int(_t * 14.0) % 2
			_px(q.x - 0.25, q.y - (0.12 if flap else 0.0), col, 2, 1)
			_px(q.x + 0.25, q.y - (0.12 if flap else 0.0), col, 2, 1)
			_px(q.x, q.y, col, 1, 1)
			return
		if age < RETURN:
			return
		_fled.erase(key)
	for b in bodies:
		if b.distance_to(p) < FLEE:
			_fled[key] = _t
			return
	# Picore : la tête descend de temps en temps.
	var peck := 1.0 if fmod(_t + h * 20.0, 3.0) < 0.3 else 0.0
	_px(p.x, p.y, col, 3, 2)
	_px(p.x + 0.375, p.y - 0.125 + peck * 0.125, col, 1, 1)
	_px(p.x - 0.125, p.y + 0.125, BIRD[0], 1, 1)


func _butterfly(cx: float, cz: float, h: float, day: float) -> void:
	var ph := h * 97.0
	var p := Vector2(cx + sin(_t * 0.5 + ph) * 4.0 + sin(_t * 1.7 + ph) * 1.0, cz + cos(_t * 0.4 + ph) * 3.0 - 1.5 + sin(_t * 3.0 + ph) * 0.3)
	var col: Color = BUTTERFLY[floori(h * 1000.0) % BUTTERFLY.size()]
	col.a = minf(1.0, day * 1.5)
	if int(_t * 10.0 + ph) % 2:
		_px(p.x - 0.125, p.y, col, 1, 1)
		_px(p.x + 0.125, p.y, col, 1, 1)
	else:
		_px(p.x - 0.25, p.y, col, 1, 2)
		_px(p.x + 0.25, p.y, col, 1, 2)


## Feuille qui tombe en se balançant, depuis la canopée (boucle de 9 s).
func _leaf(cx: float, cz: float, h: float, flora: Flora) -> void:
	if flora and flora.zone_at(cx, cz) == Flora.Zone.CLEARING:
		return
	var ph := h * 53.0
	var f := fmod(_t / 9.0 + ph, 1.0)
	var p := Vector2(cx + sin(f * 12.0 + ph) * 0.8, cz - 6.0 + f * 6.0)
	var col: Color = LEAF[floori(h * 300.0) % LEAF.size()]
	col.a = 1.0 if f < 0.9 else (1.0 - f) * 10.0
	_px(p.x, p.y, col, 2 if int(f * 30.0) % 2 else 1, 1)


func _pollen(cx: float, cz: float, i: int, j: int, day: float) -> void:
	var wind := Wind.at(cx, cz, _t) * 0.6
	for k in 2:
		var ph := Rng.hash3(i, j, 40 + k) * 100.0
		var f := fmod(_t / 14.0 + ph, 1.0)
		var p := Vector2(cx - CELL * 0.5 + f * CELL + sin(_t + ph) * 0.4 + wind, cz + sin(_t * 0.6 + ph) * 2.0 - 1.0)
		var col := POLLEN
		col.a = 0.6 * day * sin(f * PI)
		_px(p.x, p.y, col)


## Libellules au-dessus de l'eau, poissons qui sautent, grenouilles sur la berge.
func _water_life(i: int, j: int, river: River, day: float) -> void:
	var x := (i + Rng.hash3(i, j, 11)) * CELL
	if not river.bridge_near(x).is_empty():
		return
	var c := river.center(x)
	var hw := river.half_width(x)
	var h := Rng.hash3(i, j, 12)
	if h < 0.5 and day > 0.4:
		var dart := floorf(_t * 0.7 + h * 10.0)
		var p := Vector2(x + (Rng.hash3(i, int(dart), 13) - 0.5) * 6.0, c + (Rng.hash3(i, int(dart), 14) - 0.5) * hw * 1.4 - 0.8)
		_px(p.x, p.y, DRAGONFLY, 3, 1)
		if int(_t * 20.0) % 2:
			_px(p.x + 0.125, p.y - 0.125, Color(0.9, 1, 1, 0.6), 1, 1)
	# Saut de poisson toutes les ~7 s : arc puis rond dans l'eau.
	var period := 6.0 + h * 4.0
	var f := fmod(_t + h * 31.0, period)
	var fx := x + (h - 0.5) * 4.0
	var fz := c + (Rng.hash3(i, j, 15) - 0.5) * hw
	if f < 0.6:
		var a := f / 0.6
		_px(fx + a * 1.2, fz - sin(a * PI) * 0.9, FISH, 2, 1)
	elif f < 1.6:
		var r := (f - 0.6) * 0.9 + 0.2
		var col := Color(0.85, 0.92, 0.95, 0.6 * (1.6 - f))
		for k in 8:
			var a := k * TAU / 8.0
			_px(fx + 1.2 + cos(a) * r, fz + sin(a) * r * 0.5, col)
	# Grenouille sur la berge nord, saute de temps en temps.
	if h > 0.7:
		var side := -1.0 if h > 0.85 else 1.0
		var hop := fmod(_t + h * 17.0, 5.0)
		var lift := sin(clampf(hop / 0.4, 0.0, 1.0) * PI) * 0.3 if hop < 0.4 else 0.0
		var gx := x + 3.0 + float(floori((_t + h * 17.0) / 5.0) % 3) * 0.5
		var gz := c + side * (hw + 0.5) - lift
		_px(gx, gz, FROG, 2, 1)
		_px(gx + 0.25, gz - 0.125, FROG, 1, 1)


## Brume au ras de l'eau, à l'aube et la nuit : nappes claires qui dérivent vers l'est.
func _mist(cam: Vector2, half: Vector2, river: River, night: float) -> void:
	var f := DayNight.fraction(GameState.sim_time)
	var dawn := 1.0 - clampf(f / (DayNight.DAWN_END * 3.0), 0.0, 1.0)
	var amount := maxf(dawn, night * 0.55)
	if amount < 0.05:
		return
	var x := floorf((cam.x - half.x) / 6.0) * 6.0
	while x < cam.x + half.x:
		var h := Rng.hash3(floori(x / 6.0), 0, 0x3157)
		var drift := fmod(_t * 0.6 + h * 6.0, 6.0)
		var px := x + drift
		var c := river.center(px)
		var hw := river.half_width(px)
		var col := MIST
		col.a = 0.07 * amount * (0.6 + h * 0.8)
		var cy := c + sin(_t * 0.3 + h * 9.0) * 0.4
		for k in 4:
			var g := float(k)
			var r := (4.0 - g * 0.7) * 8.0
			draw_set_transform(Vector2(roundf((px + (g - 1.5) * 1.2) * 8.0), roundf(cy * 8.0)), 0.0, Vector2(1.0, clampf(hw / 4.0, 0.3, 0.6)))
			draw_circle(Vector2.ZERO, r, col)
		draw_set_transform(Vector2.ZERO)
		x += 6.0
