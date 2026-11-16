class_name HealFx
extends Node2D
## Soin reçu (planche « Puits des Âmes · Lotus de pierre ») : tant que l'unité est soignée (Puits des Âmes,
## Soigneur), de petits « + » verts naissent sur elle, montent de quelques pixels et s'effacent. Le fondu
## passe par des paliers de couleur (sombre → vif → sombre) pour que la croix garde sa forme.
## Repère : pieds de l'unité, pixels natifs.

const STEP := 0.38
const LIFE := 1.2
const RISE := 7.0
const G := [Color("#1f6a2a"), Color("#3fa83a"), Color("#7ae070"), Color("#b8f0a0"), Color("#e8ffe0")]
const OUT := Color("#0a0a0c")
const PLUS: Array[Vector2i] = [Vector2i(0, -2), Vector2i(0, -1), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0),
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)]

var view: UnitView
## Croix en vie : [instant de naissance, décalage].
var _spawns: Array = []
var _seen := -INF
var _last := -INF
var _n := 0
static var _rim: Array[Vector2i] = []


func tick() -> void:
	var u := view.unit
	var t := GameState.sim_time
	if u.healed_at > _seen:
		_seen = u.healed_at
		if t - _last >= STEP:
			_last = t
			var h := float(view.hp_y()) - 4.0
			var ox := roundf((_hash(_n, 1) - 0.5) * 18.0)
			var oy := roundf(-8.0 - _hash(_n, 2) * maxf(4.0, h - 12.0))
			_spawns.append([t, Vector2(ox, oy)])
			_n += 1
	while not _spawns.is_empty() and t - float(_spawns[0][0]) > LIFE:
		_spawns.pop_front()
	if not _spawns.is_empty() or visible:
		queue_redraw()
	visible = not _spawns.is_empty()


func _draw() -> void:
	if _rim.is_empty():
		for p in PLUS:
			for e: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := p + e
				if not PLUS.has(q) and not _rim.has(q):
					_rim.append(q)
	var t := GameState.sim_time
	for s: Array in _spawns:
		var k := clampf((t - float(s[0])) / LIFE, 0.0, 1.0)
		var al := _smooth(k / 0.3) if k < 0.3 else 1.0 - _smooth((k - 0.55) / 0.45)
		var lv := 3 if al > 0.8 else 2 if al > 0.55 else 1 if al > 0.3 else 0 if al > 0.1 else -1
		if lv < 0:
			continue
		var o: Vector2 = s[1]
		var at := Vector2(o.x, o.y - roundf((1.0 - pow(1.0 - k, 3.0)) * RISE))
		var body: Color = [G[0], G[1], G[2], G[2]][lv]
		var core: Color = [G[0], G[2], G[3], G[4]][lv]
		if lv >= 2:
			for q in _rim:
				draw_rect(Rect2(at + Vector2(q), Vector2.ONE), OUT)
		for q in PLUS:
			draw_rect(Rect2(at + Vector2(q), Vector2.ONE), core if q == Vector2i.ZERO else body)
		if lv == 3:
			draw_rect(Rect2(at + Vector2(0, -1), Vector2.ONE), G[3])
			draw_rect(Rect2(at + Vector2(-1, 0), Vector2.ONE), G[3])


static func _smooth(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


static func _hash(a: int, b: int) -> float:
	var s := sin(a * 127.1 + b * 311.7 + 17.0) * 43758.5453
	return s - floorf(s)
