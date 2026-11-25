class_name AshDeath
extends Node2D
## Mort « Souffle » d'un ennemi (planche planches/mort-ennemis-propositions.html, piste 3) : chaque pixel de la
## dernière image du corps devient deux grains d'un demi-pixel, emportés en cône vers l'arrière, qui refroidissent
## en vol et retombent en traînée de cendres. Le tas reste au sol tant que le corps existe (butin compris).
## Repère local : le sprite regarde vers +x (UnitView retourne le nœud selon le regard), le souffle part vers −x.
## Les grains sont un MultiMesh animé par shaders/ash_death.gdshader : ce script ne fait que les semer une fois
## (résultat gardé par image du sprite) et dessiner l'éclair, l'arc au sol, les fumées et la brûlure.
const SHADER := preload("res://shaders/ash_death.gdshader")
## Durée après laquelle plus rien ne bouge hors shader (s) : le dessin d'appoint cesse d'être refait.
const SETTLED := 1.2
const SPARKS := 50
const SMOKES := 8
const CACHE_MAX := 64
## Braise par camp : or pour le Credo Divin, rouge pour la Bête et le reste.
const RAMP_BETE: Array[Color] = [Color("fff3d0"), Color("ffd04a"), Color("ff8a1e"), Color("e2401a"),
		Color("a81c16"), Color("5e1414"), Color("3a2a2e")]
const RAMP_CREDO: Array[Color] = [Color("fffbe6"), Color("ffe98a"), Color("f2c038"), Color("cc8a1c"),
		Color("8a5a14"), Color("4e3a18"), Color("38302a")]
const CREDO_MORE := ["shield", "strazhar"]
const SMOKE_TONES: Array[Color] = [Color("4a4750"), Color("35333b"), Color("26252b")]

## Grains par image de sprite : clé « atlas|région » → {mm, cx, cz, maxx, bw, bh}.
static var _cache := {}
static var _images := {}
static var _quad: ArrayMesh

var _grains := MultiMeshInstance2D.new()
var _mat := ShaderMaterial.new()
var _info := {}
var _ramp: Array[Color] = RAMP_BETE
var _smoke: Array[Dictionary] = []
var _age := -1.0


func setup(frame: AtlasTexture, ax: float, ay: float, role: String) -> void:
	_info = _sow(frame, ax, ay)
	_ramp = RAMP_CREDO if Catalog.CREDO_KINDS.has(role) or CREDO_MORE.has(role) else RAMP_BETE
	_mat.shader = SHADER
	_mat.set_shader_parameter("ramp", PackedColorArray(_ramp))
	_grains.multimesh = _info["mm"]
	_grains.material = _mat
	add_child(_grains)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_instance_id())
	for i in SMOKES:
		var a := rng.randf() * TAU
		var sp := 30.0 * (0.4 + rng.randf() * 0.6)
		_smoke.append({"t0": 0.06 + rng.randf() * 0.08, "x": float(_info["cx"]) + (rng.randf() - 0.5) * float(_info["bw"]) * 0.6,
				"z": 2.0 + rng.randf() * float(_info["bh"]) * 0.6, "g": (rng.randf() - 0.5) * 6.0,
				"vx": cos(a) * sp - 60.0, "vg": sin(a) * sp * 0.25, "vz": 18.0 + rng.randf() * 30.0,
				"life": 0.45 + rng.randf() * 0.4, "r": 2.0 + rng.randf() * 1.6})


## Avance la mort à l'âge donné (s depuis le coup fatal, à la cadence de la vague).
func tick(age: float) -> void:
	if age == _age:
		return
	var moving := age < SETTLED or _age < SETTLED
	_age = age
	_mat.set_shader_parameter("age", age)
	if moving:
		queue_redraw()


func _draw() -> void:
	var t := _age
	var cx := float(_info["cx"])
	var cz := float(_info["cz"])
	var bw := float(_info["bw"])
	# Brûlure au sol, une fois le corps parti.
	if t > 0.17:
		var k := minf(1.0, (t - 0.17) / 0.12)
		_ellipse(Vector2(cx, 0), bw * 0.42 * k + 3.0, 5.0 * k + 1.0, Color(0, 0, 0, 0.2))
		_ellipse(Vector2(cx, 0), bw * 0.26 * k + 1.0, 3.0 * k, Color(0, 0, 0, 0.2))
	if t >= SETTLED:
		return
	# Arc au ras du sol, du côté où part le souffle ; pointillé quand il s'éteint.
	var u := t - 0.04
	if u > 0.0:
		var rad := 50.0 * (1.0 - exp(-u * 230.0 / 50.0 * 1.6))
		var k := rad / 50.0
		if k <= 0.97:
			var col := _ramp[mini(6, floori(k * k * 7.0))]
			var n := ceili(rad * 7.0)
			var i := 0
			while i < n:
				var a := float(i) / n * TAU
				if cos(a) <= -0.2:
					draw_rect(Rect2(roundf(cx + cos(a) * rad), roundf(sin(a) * rad * 0.5), 1, 1), col)
				i += 2 if k > 0.75 else 1
	# Fumées : petits disques pleins qui montent et rétrécissent.
	for s in _smoke:
		var v := t - float(s["t0"])
		if v <= 0.0 or v >= float(s["life"]):
			continue
		var e := (1.0 - exp(-2.0 * v)) / 2.0
		var k := v / float(s["life"])
		var r := maxf(0.5, float(s["r"]) * (1.0 - k * k))
		_ellipse(Vector2(float(s["x"]) + float(s["vx"]) * e, float(s["g"]) + float(s["vg"]) * e - float(s["z"]) - float(s["vz"]) * e),
				r, r * 0.8, SMOKE_TONES[0 if k < 0.4 else (1 if k < 0.75 else 2)])
	# Éclair du coup : étoile à quatre branches du côté frappé.
	if t < 0.06:
		var k := t / 0.06
		var r := 12.0 * (0.5 + k * 0.5)
		var at := Vector2(float(_info["maxx"]) + 2.0, -cz)
		var col := Color.WHITE if k < 0.5 else _ramp[1]
		draw_rect(Rect2(at.x - r, at.y - 0.5, 2.0 * r, 1), col)
		draw_rect(Rect2(at.x - 0.5, at.y - r, 1, 2.0 * r), col)
		draw_rect(Rect2(at.x - r * 0.3, at.y - r * 0.3, r * 0.6, r * 0.6), col)


## Ellipse pleine en rangées d'un pixel (bords en escalier, pas de lissage).
func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var rows := floori(ry)
	for y in range(-rows, rows + 1):
		var w := roundf(rx * sqrt(maxf(0.0, 1.0 - float(y * y) / (ry * ry))))
		if w > 0.0:
			draw_rect(Rect2(roundf(c.x) - w, roundf(c.y) + y, 2.0 * w, 1), col)


## Sème les grains d'une image de sprite : deux par pixel opaque, plus les étincelles.
static func _sow(frame: AtlasTexture, ax: float, ay: float) -> Dictionary:
	var key := "%s|%s" % [frame.atlas.resource_path, frame.region]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() >= CACHE_MAX:
		_cache.clear()
	if not _images.has(frame.atlas):
		var loaded := frame.atlas.get_image()
		if loaded.is_compressed():
			loaded.decompress()
		_images[frame.atlas] = loaded
	var img: Image = _images[frame.atlas]
	var r := Rect2i(frame.region)
	var px := PackedVector2Array()
	var minx := INF
	var maxx := -INF
	var top := 1.0
	var sum := Vector2.ZERO
	for y in r.size.y:
		for x in r.size.x:
			if img.get_pixel(r.position.x + x, r.position.y + y).a < 0.5:
				continue
			var p := Vector2(x - ax, ay - y)
			px.append(p)
			minx = minf(minx, p.x)
			maxx = maxf(maxx, p.x)
			top = maxf(top, p.y)
			sum += p
	var count := maxi(1, px.size())
	var centre := sum / count
	var bw := maxf(1.0, maxx - minx + 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = _quad_mesh()
	mm.instance_count = px.size() * 2 + SPARKS
	var i := 0
	for p in px:
		for _twin in 2:
			# Cône vers l'arrière ; les pixels du côté frappé partent les premiers, le haut du corps plus vite.
			var a := (rng.randf() - 0.5) * 0.8
			var sp := (120.0 + rng.randf() * 250.0) * (0.75 + 0.3 * p.y / top)
			var t0 := 0.03 + (maxx - p.x) / bw * 0.04 + rng.randf() * 0.03
			mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(p.x + 0.5, -p.y + 0.5)))
			mm.set_instance_custom_data(i, Color(-cos(a) * sp, sin(a) * sp * 0.8 + 45.0, t0, p.y))
			i += 1
	for _s in SPARKS:
		var a := (rng.randf() - 0.5) * 0.7
		var sp := 350.0 + rng.randf() * 260.0
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(centre.x, -centre.y)))
		mm.set_instance_custom_data(i, Color(-cos(a) * sp, sin(a) * sp * 0.7 + 50.0, 1.03, centre.y))
		i += 1
	var info := {"mm": mm, "cx": centre.x, "cz": centre.y, "maxx": maxx, "bw": bw, "bh": top}
	_cache[key] = info
	return info


## Carré d'un demi-pixel ; l'UV vaut le coin (0..1), le shader s'en sert pour étirer le grain.
static func _quad_mesh() -> ArrayMesh:
	if _quad == null:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.25, -0.25), Vector2(0.25, -0.25), Vector2(0.25, 0.25), Vector2(-0.25, 0.25)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		_quad = ArrayMesh.new()
		_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _quad
