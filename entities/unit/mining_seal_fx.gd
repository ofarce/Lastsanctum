extends Node2D
## Sceau équipé : « Ronde en cascade · Relais électrique ». Repère en pixels natifs,
## depuis les pieds ; l'orientation et la lévitation suivent le sprite de l'Ingénieur.

const ORBIT := 5.0
const RELAY := 2.4
const STEP := 0.24
const FLASH := 0.13
const SILVER := [Color("#202832"), Color("#465461"), Color("#6d7b88"), Color("#b5c1ca"), Color("#eff4f5")]
## Foreuse de Gorge-Cuivre portée : « Cinq billes en mèche » (planches/mods-exile-propositions.html, tour 2, C).
## Cinq petites sphères, cuivre et argent en alternance, sur l'orbite du Sceau ; quand l'Exilé creuse, elles filent
## devant lui et s'alignent en cône pointé vers la case creusée, qui tourne et crache des étincelles.
const Gear := preload("res://data/gear_items.gd")
const COPPER := [Color("#3a1e10"), Color("#7a3e1c"), Color("#b8642c"), Color("#e09450"), Color("#ffd4a0")]
const SPARK := [Color("#ffd060"), Color("#fff4c8")]
const DRILL_BALLS := 5
## Mise en mèche et retour à l'orbite (s), départ de la mèche devant la poitrine (pixels depuis les pieds).
const DRILL_IN := 0.2
const DRILL_OUT := 0.3
const DRILL_FROM := Vector2(2.0, -17.0)
var view: UnitView
var _drill_q := 0.0
var _drill_dir := Vector2.RIGHT
var _last_t := NAN


static func equipped(u: Unit) -> bool:
	return u.role == "engineer" and not u.is_enemy() and u.alive() and GameState.mining_seal


static func sphere(index: int, time: float, count: int = 3) -> Vector2:
	var angle := -PI / 2.0 + time * TAU / ORBIT + index * TAU / count
	return Vector2(-15.5 + cos(angle) * 4.5, -17.5 + sin(angle) * 9.5)


static func relay_pair(time: float) -> int:
	var phase := fposmod(time, RELAY)
	var pair := floori(phase / STEP)
	return pair if pair < 3 and fposmod(phase, STEP) < FLASH else -1


## Case que l'Exilé creuse en ce moment (centre, en unités de monde), ou null.
static func dig_target(u: Unit) -> Variant:
	if not u.working or not (u.job is Dictionary) or u.job.get("type", "") != "dig" or not u.job.has("cell"):
		return null
	var c: Dictionary = u.job["cell"]
	return Vector2(int(c["i"]) * 4.0 + 2.0, int(c["j"]) * 4.0 + 2.0)


func tick(face: int, offset: Vector2, body_shown: bool) -> void:
	var u := view.unit
	visible = equipped(u) and body_shown
	position = offset
	scale = Vector2(face, 1)
	var t := GameState.sim_time
	var dt := 0.0 if is_nan(_last_t) else clampf(t - _last_t, 0.0, 0.1)
	_last_t = t
	var target: Variant = dig_target(u) if Gear.has_module(u, "drill") else null
	if target != null:
		var d: Vector2 = target - u.pos()
		if d.length_squared() > 0.0001:
			_drill_dir = d.normalized()
		_drill_q = minf(1.0, _drill_q + dt / DRILL_IN)
	else:
		_drill_q = maxf(0.0, _drill_q - dt / DRILL_OUT)
	# En mèche, les billes passent devant le corps.
	z_index = 1 if _drill_q > 0.5 else 0
	if visible:
		queue_redraw()


func _draw() -> void:
	if Gear.has_module(view.unit, "drill"):
		_draw_drill()
		return
	var time := GameState.sim_time
	var points: Array[Vector2] = []
	for i in 3:
		points.append(sphere(i, time))
	var pair := relay_pair(time)
	if pair >= 0:
		var direction := (points[(pair + 1) % 3] - points[pair]).normalized()
		var start := points[pair] + direction * 2.25
		var end := points[(pair + 1) % 3] - direction * 2.25
		var normal := Vector2(-direction.y, direction.x)
		var previous := start.round()
		for k in range(1, 6):
			var wobble := sin(pair * 17.0 + k * 23.0 + floorf(time * 14.0) * 7.0) * 0.8 if k < 5 else 0.0
			var next := (start.lerp(end, k / 5.0) + normal * wobble).round()
			draw_line(previous, next, Color("#cce7f4"), 1.0, false)
			previous = next
	for point in points:
		var at := point.round()
		draw_circle(at, 2.5, SILVER[0])
		draw_circle(at, 1.8, SILVER[2])
		draw_rect(Rect2(at + Vector2(-1, -1), Vector2(2, 2)), SILVER[3])
		draw_rect(Rect2(at + Vector2(-1, -1), Vector2.ONE), SILVER[4])
		draw_rect(Rect2(at + Vector2(0, 1), Vector2.ONE), SILVER[1])


func _ball(at: Vector2, r: float, pal: Array) -> void:
	at = at.round()
	draw_circle(at, r + 0.6, pal[0])
	draw_circle(at, r, pal[2])
	draw_rect(Rect2(at + Vector2(-1, -1), Vector2.ONE), pal[4])
	draw_rect(Rect2(at + Vector2(0, 1), Vector2.ONE), pal[1])


func _draw_drill() -> void:
	var time := GameState.sim_time
	var q := smoothstep(0.0, 1.0, _drill_q)
	# Repère retourné avec l'Ingénieur : direction de la case remise dans ce repère (le sol est vu en 3/4).
	var dir := Vector2(_drill_dir.x * scale.x, _drill_dir.y * 0.86).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var from := DRILL_FROM + dir * 6.0
	var points: Array[Vector2] = []
	for i in DRILL_BALLS:
		var orbit := sphere(i, time, DRILL_BALLS)
		var slot := from + dir * (i * 1.6) + normal * sin(time * 20.0 + i * 1.7) * maxf(0.0, 2.2 - i * 0.45)
		points.append(orbit.lerp(slot, q))
	if q < 0.5:
		var pair := relay_pair(time)
		if pair >= 0:
			var a := points[pair % DRILL_BALLS]
			var b := points[(pair + 1) % DRILL_BALLS]
			for k in range(0, 6):
				var w := sin(pair * 17.0 + k * 23.0 + floorf(time * 14.0) * 7.0) * 0.8 if k > 0 and k < 5 else 0.0
				draw_rect(Rect2((a.lerp(b, k / 5.0) + Vector2(0, w)).round(), Vector2.ONE), SPARK[0])
	for i in DRILL_BALLS:
		var r := lerpf(1.3, maxf(0.7, 2.0 - i * 0.32), q)
		_ball(points[i], r, SILVER if i % 2 else COPPER)
	if q >= 1.0:
		# Étincelles et éclats à la pointe de la mèche, tirés de l'horloge (pas d'état à garder).
		var tip := points[DRILL_BALLS - 1] + dir * 2.0
		for k in 14:
			var born := floorf(time / 0.04) * 0.04 - k * 0.04
			var age := time - born
			if age > 0.45:
				continue
			var seed := born * 25.0
			var h1 := fposmod(sin(seed * 12.9898) * 43758.5453, 1.0)
			var h2 := fposmod(sin(seed * 78.233) * 43758.5453, 1.0)
			var v := (-dir * (6.0 + h1 * 22.0) + normal * (h2 - 0.5) * 30.0) * age + Vector2(0, 60.0 * age * age)
			draw_rect(Rect2((tip + v).round(), Vector2.ONE), Color(SPARK[1] if age < 0.15 else SPARK[0], 1.0 - age / 0.45))
