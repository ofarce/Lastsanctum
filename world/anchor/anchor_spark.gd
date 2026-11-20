class_name AnchorSpark
extends Node2D

signal engineer_reached(unit: Unit)
## Étincelle de réactivation de l'Ancre (planche etincelle-ancre-propositions.html du prototype, variante
## B « Fil d'éclair », validée). Quand l'Ancre s'éveille, une étincelle noir-argent quitte la sphère,
## traverse la caverne et le tunnel jusqu'à l'entrée, s'y divise, et chaque branche s'éteint devant une
## baliste, qui s'arme à cet instant (Simulation.SPARK_ARRIVAL). La caméra suit l'étincelle tant que le
## joueur ne la déplace pas lui-même.
## Traînée en éclair brisé qui crépite et se fragmente ; halo lumineux en paliers tramés, fort autour de
## l'étincelle et plus faible le long de la traînée. Palette noir / acier / argent / blanc : le pourpre
## reste réservé à la sphère.
##
## Enfant de WorldOverlay : espace local = pixels de l'écran. Les calculs sont faits en pixels natifs du
## monde (Proj.nat, 8 px par unité), puis décalés de world.native_offset et agrandis ×PX.
## Le halo est rendu sur la carte graphique : chaque source y dessine, palier par palier, des disques opaques
## dans le CanvasGroup « Glow » (le plus serré recouvre les autres : maximum par pixel), puis
## shaders/spark_glow.gdshader les aligne sur la grille native, trame le palier faible et ajoute la lueur
## sous les pixels de l'étincelle.

## Étincelle masquée depuis le retrait des balistes (séquence d'ouverture) : le minutage et le retour
## caméra vers l'Ingénieur restent, rien n'est dessiné et la caméra ne la suit plus.
const SHOW := false
const T1 := 0.7  # fin de la charge sur la sphère
const T2 := 3.7  # arrivée à l'entrée
const T3 := 3.95  # division
const T4 := Simulation.SPARK_ARRIVAL  # arrivée devant les balistes
const LIFE := 1.9  # durée de vie de la traînée
const END := T4 + LIFE + 0.3
const CAM_END := T4 + 1.2
const UNIT := 8.0
## Hauteur du centre de la sphère au-dessus du sol, en pixels natifs.
const SPHERE_LIFT := 35.0
## Sinusoïde du tracé dans la caverne (amortie ×0,25 dans le tunnel).
const MEANDER := [-16.0, 13.0, -11.0, 11.0, -6.0, 3.0, -3.0, 1.0]
const K0 := Color("#07070a")
const K1 := Color("#1c1d24")
const K2 := Color("#3a3c47")
const S1 := Color("#6f7482")
const S2 := Color("#a8aebb")
const S3 := Color("#d9dde6")
const WH := Color("#ffffff")
## Paliers du halo : [seuil, opacité].
## Seuils des paliers du halo, du plus fort au plus faible (opacités : shaders/spark_glow.gdshader).
const GSTEP := [0.6, 0.38, 0.2, 0.07]
## Couleur de chaque palier dans le CanvasGroup (canal rouge lu par le shader).
const GCODE := [Color(1.0, 0, 0), Color(0.75, 0, 0), Color(0.5, 0, 0), Color(0.25, 0, 0)]
const GLOW_SHADER := preload("res://shaders/spark_glow.gdshader")
const LIGHT_RGB := Color8(214, 222, 240)


## Tracé rééchantillonné tous les pixels natifs : position, normale, instant de passage de l'étincelle.
class Path:
	var p := PackedVector2Array()
	var n := PackedVector2Array()
	var tp := PackedFloat32Array()

	func last() -> Vector2:
		return p[p.size() - 1]


var world: World
var _glow := CanvasGroup.new()
var _glow_draw := Node2D.new()
var _glow_mat := ShaderMaterial.new()
var _key := INF
var _main: Path
var _branches: Array[Path] = []
var _sphere := Vector2.ZERO
var _split := Vector2.ZERO
var _cam_on := false
var _cam_last := Vector2.ZERO
var _cam_path := PackedVector2Array()
var _return_path := PackedVector2Array()
var _return_elapsed := 0.0
var _return_speaker: Unit
const RETURN_DURATION := T4
var _t := -1.0
var _px := 1.0
var _off := Vector2.ZERO
## Passe 1 : accumulation du halo, rien n'est dessiné. Passe 0 : dessin des pixels.
var _pass := 0
## Disques du halo par palier : [centre, rayon] en pixels d'écran.
var _discs: Array = [[], [], [], []]
var _drawn := false


func _ready() -> void:
	Events.game_reset.connect(_reset_camera_path)
	_glow_mat.shader = GLOW_SHADER
	_glow.material = _glow_mat
	_glow.show_behind_parent = true
	_glow.name = "Glow"
	_glow_draw.draw.connect(_draw_glow)
	_glow.add_child(_glow_draw)
	add_child(_glow)


static func _hash(i: float, j: float) -> float:
	var s := sin(i * 12.9898 + j * 78.233) * 43758.5453
	return s - floorf(s)


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65


static func _jr(v: float) -> float:
	return floorf(v + 0.5)


# ---------------------------------------------------------------- Tracés

static func _catmull(ctrl: Array[Vector2]) -> Path:
	var raw := PackedVector2Array()
	for i in ctrl.size() - 1:
		var p0 := ctrl[maxi(0, i - 1)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(ctrl.size() - 1, i + 2)]
		for k in 40:
			var u := k / 40.0
			var u2 := u * u
			raw.append(0.5 * (2.0 * p1 + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * u2 * u))
	raw.append(ctrl[ctrl.size() - 1])
	var path := Path.new()
	path.p.append(raw[0])
	var acc := 0.0
	var next := 1.0
	for i in range(1, raw.size()):
		var a := raw[i - 1]
		var b := raw[i]
		var l := a.distance_to(b)
		if l <= 0.0:
			continue
		while acc + l >= next:
			path.p.append(a.lerp(b, (next - acc) / l))
			next += 1.0
		acc += l
	var m := path.p.size()
	for i in m:
		var d := path.p[mini(m - 1, i + 2)] - path.p[maxi(0, i - 2)]
		var l := d.length()
		path.n.append(Vector2(-d.y, d.x) / (l if l > 0.0 else 1.0))
	return path


## Instant de passage de l'étincelle sur chaque point (vitesse adoucie aux extrémités).
static func _stamp(path: Path, ta: float, tb: float) -> void:
	var m := path.p.size()
	var length := float(m - 1)
	path.tp.resize(m)
	var j := 0
	for k in 4001:
		var t := ta + (tb - ta) * k / 4000.0
		var s := length * _ease(k / 4000.0)
		while j < m and j <= s:
			path.tp[j] = t
			j += 1
	while j < m:
		path.tp[j] = tb
		j += 1


static func _along(path: Path, ta: float, tb: float, t: float) -> Vector2:
	var i := clampi(roundi((path.p.size() - 1) * _ease((t - ta) / (tb - ta))), 0, path.p.size() - 1)
	return path.p[i]


## Sphère → devant l'autel → sinusoïde dans la caverne → entrée du tunnel → pied de chaque baliste.
func _build() -> void:
	var c := CaveShape.CORE * UNIT
	_sphere = Vector2(c.x, c.y - SPHERE_LIFT)
	_split = Vector2(0.0, (CaveShape.mountain_edge(0.0) + 3.5) * UNIT)
	var ctrl: Array[Vector2] = [_sphere, Vector2(c.x + 7.0, c.y - 8.0), Vector2(c.x, c.y + 28.0)]
	var y0 := c.y + 28.0
	var count := MEANDER.size() + 1
	for k in range(1, count):
		var y := y0 + (_split.y - y0) * k / count
		var in_tunnel := y / UNIT > CaveShape.CAVE_Z1
		ctrl.append(Vector2(MEANDER[k - 1] * (0.25 if in_tunnel else 1.0), y))
	ctrl.append(_split)
	_main = _catmull(ctrl)
	_stamp(_main, T1, T2)
	_branches.clear()
	for b: Dictionary in GameState.turrets:
		var d := signf(b["x"] * UNIT - _split.x)
		if d == 0.0:
			d = 1.0
		var e := Vector2(b["x"] * UNIT - d * UNIT, (b["z"] + 4.0) * UNIT)
		var path := _catmull([_split, _split + Vector2(d * 18.0, 14.0), Vector2(_split.x + (e.x - _split.x) * 0.6, _split.y + 30.0), e])
		_stamp(path, T3, T4)
		_branches.append(path)


func _heads(t: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if t < T1 or t >= T4:
		return out
	if t < T2:
		out.append(_along(_main, T1, T2, t))
	elif t < T3:
		out.append(_split)
	else:
		for b in _branches:
			out.append(_along(b, T3, T4, t))
	return out


## Temps écoulé depuis l'éveil de l'Ancre, ou −1 hors séquence.
func spark_time() -> float:
	if not GameState.orb_active or GameState.orb_finished_at == INF:
		return -1.0
	var t := GameState.sim_time - GameState.orb_finished_at
	return t if t >= 0.0 and t <= END else -1.0


# ---------------------------------------------------------------- Caméra

func _reset_camera_path() -> void:
	_cam_on = false
	_cam_path.clear()
	_return_path.clear()
	_return_speaker = null
	_key = INF


func return_to_engineer(unit: Unit) -> void:
	_cam_on = false
	_return_speaker = unit
	_return_elapsed = 0.0
	_return_path = PackedVector2Array([world.camera.cam])
	for i in range(_cam_path.size() - 1, -1, -1):
		_return_path.append(_cam_path[i])
	_return_path.append(unit.pos())


func _return_tick(delta: float) -> void:
	if not _return_speaker.alive() or _return_speaker.hidden:
		_return_path.clear()
		_return_speaker = null
		return
	_return_elapsed += delta
	var progress := clampf(_return_elapsed / (RETURN_DURATION if SHOW else 1.0), 0.0, 1.0)
	var cursor := smoothstep(0.0, 1.0, progress) * (_return_path.size() - 1)
	var i := mini(floori(cursor), _return_path.size() - 2)
	_return_path[_return_path.size() - 1] = _return_speaker.pos()
	world.camera.set_view(_return_path[i].lerp(_return_path[i + 1], cursor - i), world.camera.px)
	if progress >= 1.0:
		var speaker := _return_speaker
		_return_path.clear()
		_return_speaker = null
		engineer_reached.emit(speaker)

func _cam_target(t: float) -> Vector2:
	var ty := _branches[0].last().y - 10.0 if not _branches.is_empty() else _split.y
	if t < T1:
		return Vector2(_sphere.x, _sphere.y + 29.0)
	if t < T2:
		var h := _along(_main, T1, T2, t)
		return Vector2(h.x * 0.5, h.y + 34.0)
	if t < T3:
		return _split
	if t < T4:
		return Vector2(_split.x, lerpf(_split.y, ty, (t - T3) / (T4 - T3)))
	return Vector2(_split.x, ty)


func _follow(t: float, delta: float) -> void:
	var cam := world.camera
	if not _cam_on or t >= CAM_END:
		return
	# Le joueur a déplacé la caméra : on lui rend la main jusqu'à la fin de la séquence.
	if cam.cam.distance_to(_cam_last) > 0.01:
		_cam_on = false
		return
	var g := _cam_target(t) / UNIT
	cam.set_view(cam.cam + (g - cam.cam) * (1.0 - exp(-6.0 * delta)), cam.px)
	_cam_last = cam.cam
	_cam_path.append(cam.cam)


# ---------------------------------------------------------------- Image

func _process(delta: float) -> void:
	if world == null:
		return
	if not _return_path.is_empty():
		_return_tick(delta)
	if not SHOW:
		return
	_t = spark_time()
	if _t < 0.0:
		if _drawn:
			_drawn = false
			_clear_discs()
			queue_redraw()
			_glow_draw.queue_redraw()
		return
	_drawn = true
	if GameState.orb_finished_at != _key:
		_key = GameState.orb_finished_at
		_build()
		_cam_on = true
		_cam_last = world.camera.cam
		_cam_path = PackedVector2Array([_cam_last])
	_follow(_t, delta)
	_px = float(world.camera.px)
	_off = world.native_offset
	_glow_mat.set_shader_parameter("px", _px)
	_clear_discs()
	_pass = 1
	_fx(_t)
	_pass = 0
	queue_redraw()
	_glow_draw.queue_redraw()


func _draw() -> void:
	if _t >= 0.0 and _main != null:
		_fx(_t)


func _clear_discs() -> void:
	for d: Array in _discs:
		d.clear()


## Paliers du plus faible au plus fort : chaque disque recouvre ceux des paliers inférieurs.
func _draw_glow() -> void:
	for j in range(3, -1, -1):
		for d: Array in _discs[j]:
			_glow_draw.draw_circle(d[0], d[1], GCODE[j])


func _fx(t: float) -> void:
	_trail(t)
	_events(t)
	for h in _heads(t):
		_head(h.x, h.y, t, 0.0)


func _npx(x: float, y: float, c: Color) -> void:
	if _pass == 1:
		return
	draw_rect(Rect2(_jr(x + _off.x) * _px, _jr(y + _off.y) * _px, _px, _px), c)


## Source de halo : intensité s au centre, décroissance (1 − d/r)^1,4. Chaque palier devient un disque dont
## le rayon est la distance où l'intensité passe sous son seuil.
func _light(x: float, y: float, r: float, s: float) -> void:
	if _pass != 1 or s <= 0.0 or r <= 0.0:
		return
	var c := (Vector2(_jr(x + _off.x), _jr(y + _off.y)) + Vector2(0.5, 0.5)) * _px
	for j in 4:
		var th: float = GSTEP[j]
		if s <= th:
			continue
		var rd := r * (1.0 - pow(th / s, 1.0 / 1.4))
		if rd >= 0.5:
			_discs[j].append([c, rd * _px])


func _light_seg(a: Vector2, b: Vector2, r: float, s: float) -> void:
	if _pass != 1:
		return
	var n := maxi(1, ceili(a.distance_to(b) / 3.0))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		_light(p.x, p.y, r, s)


func _line(a: Vector2, b: Vector2, c: Color, thick: bool) -> void:
	var n := maxi(1, ceili(a.distance_to(b)))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		if thick:
			_npx(p.x - 1.0, p.y, c)
			_npx(p.x + 1.0, p.y, c)
			_npx(p.x, p.y - 1.0, c)
			_npx(p.x, p.y + 1.0, c)
		else:
			_npx(p.x, p.y, c)


func _ring(x: float, y: float, rx: float, ry: float, cols: Array[Color], step := 1.0) -> void:
	var n := maxi(8, ceili(rx * TAU / step))
	for k in n:
		var a := float(k) / n * TAU
		_npx(x + cos(a) * rx, y + sin(a) * ry, cols[k % cols.size()])


func _head(x: float, y: float, t: float, big: float) -> void:
	var f := int(floorf(t * 14.0))
	var r := 9.0 + big * 4.0 + (1.0 if f % 3 == 0 else 0.0)
	_light(x, y, r + 13.0, 1.05)
	if _pass == 1:
		return
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var d := absi(dx) + absi(dy)
			if d == 3 or (d == 4 and absi(dx) < 3 and absi(dy) < 3):
				_npx(x + dx, y + dy, K0)
			elif d == 2:
				_npx(x + dx, y + dy, S1 if (dx + dy + f) & 1 else K1)
	var diag := f % 2 == 1
	var arm := 4 + (2 if f % 4 == 1 else 0) + int(big * 2.0)
	for k in range(-arm - 1, arm + 2):
		if k == 0:
			continue
		var c := K0 if absi(k) > arm else S2 if absi(k) == arm else S3
		if diag:
			_npx(x + k * 0.75, y + k * 0.75, c)
			_npx(x + k * 0.75, y - k * 0.75, c)
		else:
			_npx(x + k, y, c)
			_npx(x, y + k, c)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_npx(x + dx, y + dy, S3 if dx != 0 and dy != 0 else WH)
	if f % 3 == 1:
		_npx(x + arm + 2, y - arm - 1, S3)
		_npx(x - arm - 1, y + arm, S2)


func _mote(x: float, y: float, k: int) -> void:
	_npx(x, y, WH if k & 1 else S3)
	_npx(x + 1.0, y, K0)
	_npx(x - 1.0, y, K0)
	_npx(x, y + 1.0, K0)
	_npx(x, y - 1.0, K0)


## Traînée « fil d'éclair » : ligne brisée qui crépite, se fragmente et se tord en s'éteignant.
func _trail(t: float) -> void:
	var fr := floorf(t * 16.0)
	var glow: Array = []
	var core: Array = []
	var paths: Array[Path] = [_main]
	paths.append_array(_branches)
	for pi in paths.size():
		var path := paths[pi]
		var has_prev := false
		var prev := Vector2.ZERO
		for i in range(0, path.p.size(), 5):
			if path.tp[i] > t:
				break
			var a := t - path.tp[i]
			var I := 1.0 - a / LIFE
			if I <= 0.0:
				has_prev = false
				continue
			var key := float(i + pi * 999)
			var amp := 1.0 + (1.0 - I) * 3.5 if i > 0 else 0.0
			var pt := path.p[i] + path.n[i] * ((_hash(key, fr) - 0.5) * 2.0 * amp)
			if has_prev and _hash(key, fr + 7.0) > (1.0 - I) * 0.85:
				core.append([prev, pt, WH if a < 0.12 else S3 if I > 0.6 else S2 if I > 0.35 else K2])
				if I > 0.45:
					glow.append([prev, pt])
				_light_seg(prev, pt, 6.0 if a < 0.3 else 4.5, (0.7 if a < 0.3 else 0.5) * I)
			if i % 45 == 0 and a < 0.7 and i > 0:
				var nn := path.n[i]
				var ang := atan2(nn.y, nn.x) + (0.0 if _hash(i, fr + 3.0) > 0.5 else PI) + (_hash(i, fr + 5.0) - 0.5)
				var l := 3.0 + _hash(i, fr + 9.0) * 6.0 * (1.0 - a)
				core.append([pt, pt + Vector2(cos(ang), sin(ang)) * l, S1])
			prev = pt
			has_prev = true
	if _pass == 1:
		return
	for s: Array in glow:
		_line(s[0], s[1], K0, true)
	for s: Array in core:
		_line(s[0], s[1], s[2], false)


## Charge sur la sphère, division à l'entrée, impact devant chaque baliste.
func _events(t: float) -> void:
	var sp := _sphere
	if t < T1 + 0.35:
		if t < T1:
			var u := t / T1
			_light(sp.x, sp.y, 8.0 + 14.0 * u, 0.55 * u)
			var R := 6.0 + 26.0 * (1.0 - u * u)
			_ring(sp.x, sp.y, R, R * 0.9, [S3, S3, K0])
			_ring(sp.x, sp.y, R + 1.0, R * 0.9 + 1.0, [K0])
			if u > 0.3:
				_ring(sp.x, sp.y, R * 0.6, R * 0.55, [S2, K0], 2.0)
			for k in 8:
				var a := k * 0.785 + t * 3.0 * (1.0 if k & 1 else -1.0)
				var d := 6.0 + 34.0 * (1.0 - u) * (1.0 + 0.2 * (k % 3))
				_mote(sp.x + cos(a) * d, sp.y + sin(a) * d * 0.9, k)
			if u > 0.75:
				_head(sp.x, sp.y, t, (u - 0.75) * 2.0)
		else:
			var v := (t - T1) / 0.35
			_light(sp.x, sp.y, 18.0, 0.7 * (1.0 - v))
			var cols: Array[Color] = []
			cols.assign([WH, WH, K0] if v < 0.5 else [S1, K0])
			_ring(sp.x, sp.y, 8.0 + v * 26.0, 8.0 + v * 23.0, cols)
	var sl := _split
	if t >= T2 and t < T3 + 0.5:
		if t < T3:
			_head(sl.x, sl.y, t, 1.0)
		if t >= T3 - 0.05:
			var v := (t - T3 + 0.05) / 0.55
			var rx := 4.0 + v * 30.0
			_light(sl.x, sl.y, 22.0 * (1.0 - v * 0.5), 0.75 * (1.0 - v))
			var cols: Array[Color] = []
			cols.assign([S3, K0] if v < 0.4 else [S1, K0, K0])
			_ring(sl.x, sl.y, rx, rx * 0.45, cols)
			if v < 0.3:
				_ring(sl.x, sl.y, rx * 0.6, rx * 0.27, [K0], 2.0)
	if t >= T4 and t < T4 + 0.6:
		var u := (t - T4) / 0.6
		for b in _branches:
			var e := b.last()
			_light(e.x, e.y - 6.0, 16.0 * (1.0 - u * 0.5), 0.85 * (1.0 - u))
			if u < 0.55:
				var h := 30.0 * (1.0 - u / 0.55)
				var y := 0.0
				while y < h:
					_npx(e.x, e.y - y, WH if y < 4.0 or u < 0.2 else S3)
					if y < h * 0.7:
						_npx(e.x - 1.0, e.y - y, K0)
						_npx(e.x + 1.0, e.y - y, K0)
					y += 1.0
			var rx := 3.0 + u * 22.0
			var cols: Array[Color] = []
			cols.assign([S3, K0] if u < 0.5 else [S1])
			_ring(e.x, e.y, rx, rx * 0.42, cols)
			if u < 0.25:
				_head(e.x, e.y, t, 0.0)


## Sources pour l'éclairage d'ambiance : creusent l'obscurité autour de l'étincelle et des impacts.
func lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := spark_time()
	if not SHOW or t < 0.0 or _main == null or _key != GameState.orb_finished_at:
		return out
	for h in _heads(t):
		out.append({"x": h.x / UNIT, "z": h.y / UNIT, "r": 5.0, "rgb": LIGHT_RGB, "glow": 0.2})
	if t >= T4 and t < T4 + 0.6:
		for b in _branches:
			var e := b.last()
			out.append({"x": e.x / UNIT, "z": e.y / UNIT, "r": 6.0, "rgb": LIGHT_RGB, "glow": 0.25})
	return out
