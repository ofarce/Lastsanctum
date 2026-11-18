class_name PoolView
extends Node2D
## Bassin souterrain (piste 01) posé au sol, sous les objets triés : forme organique précalculée
## (TerrainState.pool_field) dans une texture lue par cave_pool.gdshader, galets et mousse sur la
## berge, gouttes et ronds dans l'eau, ronds aux pieds des unités qui traversent le haut-fond.

const SHADER := preload("res://shaders/cave_pool.gdshader")
const OUT := Color8(11, 9, 11)
const RING := Color8(127, 155, 184)
const DROP := Color8(169, 189, 214)

var state: TerrainState
var pool: Dictionary
var origin := Vector2.ZERO
var size := Vector2i.ZERO
var _water := Sprite2D.new()
var _details := Sprite2D.new()
var _fx := Node2D.new()
## Points d'impact des gouttes (px, relatifs au nœud).
var _drops: Array[Vector2] = []


func setup(terrain_state: TerrainState, p: Dictionary) -> void:
	state = terrain_state
	pool = p
	var c: Vector2 = p["center"]
	name = "Pool_%d_%d" % [roundi(c.x), roundi(c.y)]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for b: Vector4 in p["balls"]:
		lo = lo.min(Vector2(b.x - b.z * 1.9, b.y - b.w * 1.9))
		hi = hi.max(Vector2(b.x + b.z * 1.9, b.y + b.w * 1.9))
	origin = (lo * 8.0).floor()
	size = Vector2i(((hi - lo) * 8.0).ceil()) + Vector2i(2, 2)
	position = origin
	_build()
	visible = false


func _build() -> void:
	var data := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var det := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var field := PackedFloat32Array()
	field.resize(size.x * size.y)
	for y in size.y:
		for x in size.x:
			field[y * size.x + x] = TerrainState.pool_field(pool, (origin.x + x + 0.5) / 8.0, (origin.y + y + 0.5) / 8.0)
	var f := func(x: int, y: int) -> float:
		return 0.0 if x < 0 or y < 0 or x >= size.x or y >= size.y else field[y * size.x + x]
	for y in size.y:
		for x in size.x:
			var v: float = field[y * size.x + x]
			if v < TerrainState.POOL_WET:
				continue
			# Berge mouillée : sol assombri, plus fort près de l'eau, hors de la roche.
			if not state.is_gallery((origin.x + x) / 8.0, (origin.y + y) / 8.0):
				continue
			if v < TerrainState.POOL_EDGE:
				data.set_pixel(x, y, Color(0, 0, (v - TerrainState.POOL_WET) / (TerrainState.POOL_EDGE - TerrainState.POOL_WET) * 0.6 + 0.4, 1))
				var hsh := Rng.hash3(x, y, pool["seed"])
				if v > 0.7 and hsh > 0.985:
					det.set_pixel(x, y, Color8(78, 88, 104))
					det.set_pixel(mini(x + 1, size.x - 1), y, Color8(78, 88, 104))
					if y + 1 < size.y:
						det.set_pixel(x, y + 1, OUT)
						det.set_pixel(mini(x + 1, size.x - 1), y + 1, OUT)
				elif v > 0.75 and hsh < 0.02:
					det.set_pixel(x, y, Color8(79, 107, 58))
					det.set_pixel(mini(x + 1, size.x - 1), y, Color8(108, 138, 74))
				continue
			var edge: bool = f.call(x, y - 1) < 1.0 or f.call(x - 1, y) < 1.0 or f.call(x + 1, y) < 1.0 or f.call(x, y + 1) < 1.0
			var depth := clampf((v - 1.0) / 2.2, 0.01, 1.0)
			var lip := 1.0 if f.call(x, y - 2) < 1.0 else 0.0
			data.set_pixel(x, y, Color(depth, 1.0 if edge else 0.0, lip, 1))
			if depth > 0.35 and Rng.hash3(x, y, pool["seed"] + 1) > 0.9993 and _drops.size() < 3:
				_drops.append(Vector2(x, y))
	_water.texture = ImageTexture.create_from_image(data)
	_water.centered = false
	_water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("size", Vector2(size))
	_water.material = m
	add_child(_water)
	_details.texture = ImageTexture.create_from_image(det)
	_details.centered = false
	add_child(_details)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _process(_delta: float) -> void:
	var c: Vector2 = pool["center"]
	visible = state.is_gallery_open(c.x, c.y)
	if visible:
		_fx.queue_redraw()


func _draw_fx() -> void:
	var t := GameState.sim_time
	for i in _drops.size():
		var target := _drops[i]
		var per := 1.9
		var ph := fmod(t + i * 0.7, per) / per
		if ph < 0.6:
			var y := target.y - 44.0 + ph / 0.6 * 44.0
			_px(Vector2(target.x, y), DROP)
		else:
			var r := (ph - 0.6) / 0.4
			for ring in 2:
				var rr := r * 12.0 - ring * 4.0
				if rr > 0.0:
					_ring(target, rr, (1.0 - r) * 0.9, float(i))
			if r < 0.25:
				for k in 4:
					_px(target + Vector2((k - 1.5) * 2.0, -2.0 - r * 8.0 + absf(k - 1.5)), Color8(199, 212, 228))
	# Ronds aux pieds des unités qui traversent l'eau.
	for u in GameState.units:
		if not u.alive() or u.hidden:
			continue
		if TerrainState.pool_field(pool, u.x, u.z) > TerrainState.POOL_EDGE:
			var p := Vector2(u.x, u.z) * 8.0 - origin
			_ring(p, 5.0 + sin(t * 4.0), 0.7, 0.0)


func _ring(c: Vector2, r: float, a: float, s: float) -> void:
	var n := maxi(12, roundi(r * 5.0))
	for k in n:
		var ang := TAU * k / n
		var wob := 1.0 + 0.15 * sin(ang * 3.0 + s)
		var p := c + Vector2(cos(ang) * r * wob, sin(ang) * r * 0.38 * wob)
		if TerrainState.pool_field(pool, (origin.x + p.x) / 8.0, (origin.y + p.y) / 8.0) > 1.2:
			_px(p, Color(RING, a))


func _px(p: Vector2, c: Color) -> void:
	_fx.draw_rect(Rect2(p.round(), Vector2.ONE), c)
