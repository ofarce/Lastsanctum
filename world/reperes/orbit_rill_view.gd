class_name OrbitRillView
extends Node2D
## Rigoles des veilleuses de l'Orbite (OrbitGate.rills) : un canal au sol par gardien, de son arène au pied de sa
## niche sur la porte, de la couleur de sa flamme. La lumière y coule vers la porte en battements ; à la chute du
## gardien, elle s'éteint depuis l'arène (front donné par OrbitGateView) et le canal reste gris. Sous les sprites.

const LIP := Color("#0e1016")
const CORE := {"a": [Color("#6e4e18"), Color("#b98c34"), Color("#fff2c0")], "m": [Color("#45205e"), Color("#8048a0"), Color("#ecd0f8")]}
const DEAD := Color("#46464e")

var world: World
var gate: OrbitGateView
var _pts := {}
var _cum := {}
var _glow := Node2D.new()


func setup(w: World, g: OrbitGateView) -> void:
	world = w
	gate = g
	name = "RigolesOrbite"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var r := OrbitGate.rills(w.terrain_state)
	for k: String in r:
		var pts := PackedVector2Array()
		var cum := PackedFloat32Array()
		var acc := 0.0
		for p: Vector2 in r[k]:
			var n := Proj.nat(p.x, 0.0, p.y).round() + Vector2(0.5, 0.5)
			if not pts.is_empty():
				acc += pts[pts.size() - 1].distance_to(n)
			pts.append(n)
			cum.append(acc)
		_pts[k] = pts
		_cum[k] = cum
		g.rill_len[k] = acc
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _process(_delta: float) -> void:
	queue_redraw()
	_glow.queue_redraw()


## Morceau de la ligne entre les abscisses s0 et s1 (px natifs).
func _part(k: String, s0: float, s1: float) -> PackedVector2Array:
	var pts: PackedVector2Array = _pts[k]
	var cum: PackedFloat32Array = _cum[k]
	var out := PackedVector2Array()
	if s1 <= s0:
		return out
	for i in pts.size():
		if i > 0 and cum[i] > s0 and cum[i - 1] < s0:
			out.append(_at(k, s0))
		if cum[i] >= s0 and cum[i] <= s1:
			out.append(pts[i])
		if i > 0 and cum[i] > s1 and cum[i - 1] < s1:
			out.append(_at(k, s1))
			break
	if out.size() == 1:
		out.append(out[0] + Vector2(0.01, 0))
	return out


func _at(k: String, s: float) -> Vector2:
	var pts: PackedVector2Array = _pts[k]
	var cum: PackedFloat32Array = _cum[k]
	for i in range(1, pts.size()):
		if cum[i] >= s:
			var u := (s - cum[i - 1]) / maxf(0.001, cum[i] - cum[i - 1])
			return pts[i - 1].lerp(pts[i], u)
	return pts[pts.size() - 1]


func _view() -> Rect2:
	return (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(16.0)


func _draw() -> void:
	if gate == null:
		return
	var t := GameState.sim_time
	var view := _view()
	for k: String in _pts:
		var pts: PackedVector2Array = _pts[k]
		if pts.size() < 2:
			continue
		var L: float = _cum[k][pts.size() - 1]
		var fr := minf(gate.front(k), L)
		var alive := gate.age(k) < 0.0
		draw_polyline(pts, LIP, 3.0)
		var dead := _part(k, 0.0, fr)
		if dead.size() >= 2:
			draw_polyline(dead, DEAD, 1.0)
		var lit := _part(k, fr, L)
		if lit.size() >= 2:
			draw_polyline(lit, CORE[k][1], 1.0)
		# Battements : ils avancent vers la porte ; après la chute, plus aucun ne part derrière le front.
		var s := fposmod(t * OrbitGateView.FLOW_V, OrbitGateView.FLOW_GAP)
		while s < L:
			if s >= fr + (0.0 if alive else 1.0):
				var p := _at(k, s)
				if view.has_point(p):
					draw_rect(Rect2(p - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), CORE[k][2])
			s += OrbitGateView.FLOW_GAP


func _draw_glow() -> void:
	if gate == null:
		return
	var t := GameState.sim_time
	var view := _view()
	for k: String in _pts:
		var pts: PackedVector2Array = _pts[k]
		if pts.size() < 2:
			continue
		var L: float = _cum[k][pts.size() - 1]
		var fr := minf(gate.front(k), L)
		var lit := _part(k, fr, L)
		var c: Color = CORE[k][1]
		if lit.size() >= 2:
			_glow.draw_polyline(lit, Color(c.r * 0.14, c.g * 0.14, c.b * 0.14), 5.0)
		var s := fposmod(t * OrbitGateView.FLOW_V, OrbitGateView.FLOW_GAP)
		while s < L:
			if s >= fr:
				var p := _at(k, s)
				if view.has_point(p):
					_glow.draw_circle(p, 3.0, Color(c.r * 0.18, c.g * 0.18, c.b * 0.18))
			s += OrbitGateView.FLOW_GAP
