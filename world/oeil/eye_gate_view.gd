class_name EyeGateView
extends Node2D
## Porte de chair du couloir nord de la salle de l'Œil (TerrainState.eye_gate) : une membrane pâle tendue entre
## les parois, plissée, veinée de carmin, qui bat lentement. Elle se déchire et s'efface en OPEN s quand l'Œil
## meurt (eye_gate_closed devient faux), puis disparaît. Enfant de YSort, trié sur le bas de la porte.

const H := 44
const FRAMES := 4
const FPS := 3.0
const OPEN := 1.6
const PALE := [Color("#2c2024"), Color("#4c3a3c"), Color("#76605e"), Color("#a08a82"), Color("#c8b4a8"), Color("#ecdcd0")]
const BLOOD := [Color("#4a0a0e"), Color("#7e1216"), Color("#b41c20"), Color("#e2382e")]
const OUT := Color("#0b090b")
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

var state: TerrainState
var _tex: Array[ImageTexture] = []
var _w := 0
var _opened_at := INF


func setup(st: TerrainState) -> void:
	state = st
	name = "EyeGate"
	var half := TerrainState.EYE_GATE_HALF
	_w = roundi(half * 2.0 * Proj.K)
	# Bas de la porte : bord sud de la rangée de cases.
	var gj := floori(TerrainState.frontier_z() / 4.0)
	position = Proj.nat(-half, 0.0, gj * 4.0 + 4.0).round()
	for f in FRAMES:
		_tex.append(_frame(f))


func _process(_delta: float) -> void:
	if state == null:
		return
	if not state.eye_gate_closed and _opened_at == INF:
		_opened_at = GameState.sim_time
	var k := 0.0 if _opened_at == INF else clampf((GameState.sim_time - _opened_at) / OPEN, 0.0, 1.0)
	visible = k < 1.0 and (state.is_gallery_open(0.0, TerrainState.frontier_z() + 2.0) or state.is_gallery_open(0.0, TerrainState.eye_room_center().y))
	modulate = Color(1.0 + 0.8 * k, 1.0, 1.0, 1.0 - k * k)
	scale = Vector2(1.0, 1.0 - 0.7 * k)
	if visible:
		queue_redraw()


func _draw() -> void:
	var f := floori(GameState.sim_time * FPS) % FRAMES
	draw_texture(_tex[f], Vector2(0, -H))


static func _bay(x: int, y: int) -> float:
	return (BAYER[posmod(y, 4)][posmod(x, 4)] + 0.5) / 16.0


func _frame(f: int) -> ImageTexture:
	var img := Image.create(_w, H, false, Image.FORMAT_RGBA8)
	var ph := f * TAU / FRAMES
	var fill := {}
	for y in H:
		for x in _w:
			# Membrane : bord supérieur en arc, plis verticaux qui ondulent, bas tendu au sol.
			var u := float(x) / (_w - 1) * 2.0 - 1.0
			var top := 6.0 + 10.0 * u * u + 2.0 * sin(u * 7.0 + ph * 0.5)
			if y < top:
				continue
			var fold := sin(x * 0.55 + sin(y * 0.12 + ph) * 1.4)
			var v := 0.55 + 0.22 * fold - 0.25 * absf(u) + 0.12 * (1.0 - float(y) / H) - (0.2 if y > H - 4 else 0.0)
			var fv := clampf(v, 0.0, 1.0) * (PALE.size() - 1)
			var i := floori(fv)
			var c: Color = PALE[mini(PALE.size() - 1, i + 1 if fv - i > _bay(x, y) else i)]
			img.set_pixel(x, y, c)
			fill[Vector2i(x, y)] = true
	# Veines carmin qui partent du sol, plus vives sur la trame qui bat.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for k in 7:
		var x := 8.0 + rng.randf() * (_w - 16)
		var y := H - 2.0
		var a := -PI / 2.0 + (rng.randf() - 0.5) * 0.8
		for s in 40:
			a += (rng.randf() - 0.5) * 0.5
			x += cos(a)
			y += sin(a)
			var p := Vector2i(roundi(x), roundi(y))
			if not fill.has(p):
				break
			var lit := (s + f * 3) % 12 < 4
			img.set_pixelv(p, BLOOD[3] if lit else BLOOD[1 + (s % 2)])
	# Trois yeux à demi clos.
	for e: Vector2i in [Vector2i(_w / 4, 20), Vector2i(_w / 2, 14), Vector2i(3 * _w / 4, 22)]:
		for dx in range(-2, 3):
			if fill.has(e + Vector2i(dx, 0)):
				img.set_pixelv(e + Vector2i(dx, 0), BLOOD[3] if f % 2 == 0 or absf(dx) < 2 else BLOOD[2])
				img.set_pixelv(e + Vector2i(dx, -1), OUT)
	for y in H:
		for x in _w:
			if fill.has(Vector2i(x, y)):
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if fill.has(Vector2i(x, y) + o):
					img.set_pixel(x, y, OUT)
					break
	return ImageTexture.create_from_image(img)
