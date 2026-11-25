extends Node2D
## Garde de la Martyre (sim/martyre.gd, WARD_MAX charges) : même rendu que le Voile de l'Ingénieur
## (entities/unit/veil_fx.gd). Liseré d'améthyste qui bat autour de la silhouette ; il couvre le corps depuis la
## poitrine en proportion des charges restantes. Tir absorbé (martyre_ward_absorb_at) : silhouette blanchie,
## onde violette, la part perdue du liseré éclate et tombe ; il repousse depuis la poitrine pendant la recharge.

const Veil := preload("res://entities/unit/veil_fx.gd")
var view: UnitView
var _frame: Texture2D
var _offset := Vector2.ZERO


func tick(body: Sprite2D, body_shown: bool) -> void:
	var u := view.unit
	visible = u.alive() and u == GameState.martyre and body_shown and body.texture != null
	if not visible:
		return
	position = body.position
	scale = body.scale
	_frame = body.texture
	_offset = body.offset
	queue_redraw()


func _px(p: Vector2, c: Color, a: float = 1.0) -> void:
	if a > 0.0:
		draw_rect(Rect2((_offset + p).round(), Vector2.ONE), Color(c, minf(1.0, a)))


func _draw() -> void:
	if _frame == null:
		return
	var V: Array = Veil.V
	var t := GameState.sim_time
	var s := Veil.shape(_frame)
	var ct: PackedVector2Array = s["ct"]
	var sz := _frame.get_size()
	var chest := Vector2(sz.x * 0.5, sz.y * 0.55)
	var reach := sz.length() * 0.55
	var ward := GameState.martyre_ward
	var r := reach * ward / Martyre.WARD_MAX
	var full := reach * floorf(ward) / Martyre.WARD_MAX
	var k := t - GameState.martyre_ward_absorb_at
	if k < Veil.WHITE_T:
		for p in s["fill"]:
			_px(p, Color.WHITE, 0.55)
		for p in ct:
			_px(p, Color.WHITE)
	else:
		var pulse := 0.8 + 0.15 * sin(t * 3.0)
		for p in ct:
			var d := p.distance_to(chest)
			if d < full:
				_px(p, V[4], pulse)
			elif d < r:
				_px(p, V[3], 0.6)
		if k < Veil.BRIGHT_T:
			for p in s["hl"]:
				if p.distance_to(chest) < full:
					_px(p, V[3], 0.85 * (1.0 - k / Veil.BRIGHT_T))
	# Éclats : la tranche perdue au dernier tir tombe.
	if k < Veil.SHATTER_T:
		var q := k / Veil.SHATTER_T
		var lost := reach * minf(float(Martyre.WARD_MAX), floorf(ward) + 1.0) / Martyre.WARD_MAX
		for i in range(0, ct.size(), 2):
			var p := ct[i]
			var d := p.distance_to(chest)
			if d < full or d >= lost:
				continue
			var fall := q * q * (10.0 + Veil._hash(i) * 30.0)
			var dx := (p.x - chest.x) * 0.25 * q + (Veil._hash(i + 7) - 0.5) * q * 8.0
			_px(p + Vector2(dx, fall), V[4], 1.0 - q)
			_px(p + Vector2(dx + 1.0, fall), V[2], 1.0 - q)
	if k < 0.4:
		var q := k / 0.4
		_ring(chest, sz.x * 0.3 + q * 16.0, V[4], 1.0 - q)
		_ring(chest, sz.x * 0.26 + q * 12.0, V[3], (1.0 - q) * 0.6)


func _ring(c: Vector2, rad: float, col: Color, alpha: float) -> void:
	var n := maxi(8, roundi(rad * 7.0))
	var seen := {}
	for i in n + 1:
		var a := TAU * i / n
		var p := (c + Vector2(cos(a), sin(a)) * rad).round()
		if seen.has(p):
			continue
		seen[p] = true
		_px(p, col, alpha)
