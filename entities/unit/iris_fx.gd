extends Node2D
## Iris de la Matrice porté : « Œil-satellite » (planches/mods-exile-propositions.html, Iris C). Un orbe de métal
## flotte au-dessus de l'épaule arrière, pupille carmin qui regarde autour de lui. Quand un ennemi caché derrière
## la roche est repéré (il apparaît alors sur la minicarte), la pupille se fige vers lui, l'orbe flashe et lance
## deux arcs de sonar dans sa direction. Repère en pixels natifs, depuis les pieds, comme le Sceau de minage.

const Gear := preload("res://data/gear_items.gd")
const CENTER := Vector2(-12.0, -33.0)
const CARMIN := [Color("#3a0c10"), Color("#8a1a20"), Color("#d8402a"), Color("#f0a040"), Color("#fff0b0")]
const BRASS := Color("#d0a038")
const BRASS_DARK := Color("#8a6420")
const METAL := Color("#2a2430")
## Écoute des ennemis cachés (s), pause minimale entre deux pings (s), durée du ping (s), portée des arcs (px).
const SCAN := 0.25
const PING_GAP := 2.0
const PING := 1.3
const ARC_REACH := 40.0
var view: UnitView
var _known := {}
var _scan_at := -INF
var _ping_at := -INF
var _dir := Vector2.RIGHT


static func worn(u: Unit) -> bool:
	return u.role == "engineer" and not u.is_enemy() and u.alive() and Gear.has_module(u, "iris")


func tick(face: int, offset: Vector2, body_shown: bool) -> void:
	var u := view.unit
	visible = worn(u) and body_shown
	position = offset
	scale = Vector2(face, 1)
	if not visible:
		_known.clear()
		return
	var t := GameState.sim_time
	if t - _scan_at >= SCAN:
		_scan_at = t
		_scan(u, t)
	queue_redraw()


## Ennemis repérés à travers la roche (même règle que la minicarte) ; un nouveau venu déclenche le ping.
func _scan(u: Unit, t: float) -> void:
	if view.world == null:
		return
	var seen := {}
	var fresh: Variant = null
	for e: Variant in GameState.enemies:
		if e.hidden or e.hp <= 0.0 or view.world.fog.visible_at(Vector2(e.x, e.z)):
			continue
		var id: int = e.get_instance_id()
		seen[id] = true
		if not _known.has(id) and (fresh == null or u.pos().distance_squared_to(e.pos()) < u.pos().distance_squared_to(fresh.pos())):
			fresh = e
	_known = seen
	if fresh != null and t - _ping_at >= PING_GAP:
		_ping_at = t
		var d := Vector2(float(fresh.x) - u.x, float(fresh.z) - u.z)
		_dir = d.normalized() if d.length_squared() > 0.0001 else Vector2.RIGHT


func _draw() -> void:
	var t := GameState.sim_time
	var k := t - _ping_at
	var pinging := k >= 0.0 and k < PING
	# Le repère est retourné avec l'Ingénieur : on remet la direction de la cible dans ce repère.
	var dir := Vector2(_dir.x * scale.x, _dir.y)
	var c := (CENTER + Vector2(0, roundf(sin(t * 2.0) * 1.2))).round()
	var look := Vector2(signf(dir.x) if absf(dir.x) > 0.38 else 0.0, signf(dir.y) if absf(dir.y) > 0.38 else 0.0) if pinging \
		else Vector2(roundf(sin(t * 0.9) * 1.2), 0)
	var flash := pinging and k < 0.15
	# Lueur sous l'orbe.
	draw_rect(Rect2(c + Vector2(0, 4), Vector2.ONE), Color(CARMIN[2], 0.25 + 0.15 * sin(t * 4.0)))
	for y in range(-2, 3):
		for x in range(-2, 3):
			var d := x * x + y * y
			if d > 5:
				continue
			draw_rect(Rect2(c + Vector2(x, y), Vector2.ONE), BRASS_DARK if d >= 4 else METAL)
	draw_rect(Rect2(c + Vector2(-1, -2), Vector2(2, 1)), BRASS)
	draw_rect(Rect2(c + look, Vector2.ONE), CARMIN[4] if flash else CARMIN[2])
	draw_rect(Rect2(c + look + Vector2(0, 1), Vector2.ONE), CARMIN[1])
	if flash:
		_ring(c, 3.0, CARMIN[4], 0.8, 0.0, TAU)
	if pinging:
		var a := dir.angle()
		for i in 2:
			var q := (k - 0.05 - i * 0.22) / 0.9
			if q > 0.0 and q < 1.0:
				_ring(c, 4.0 + q * ARC_REACH, CARMIN[2], 1.0 - q, a - 0.5, a + 0.5)


## Arc au pixel près (pas de lissage), comme les autres effets 16 bits.
func _ring(c: Vector2, r: float, col: Color, alpha: float, from: float, to: float) -> void:
	var n := maxi(8, roundi(r * 7.0 * (to - from) / TAU))
	var seen := {}
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		var p := (c + Vector2(cos(a), sin(a)) * r).round()
		if seen.has(p):
			continue
		seen[p] = true
		draw_rect(Rect2(p, Vector2.ONE), Color(col, alpha))
