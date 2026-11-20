class_name RainView
extends Control
## Pluie et éclairs (core/weather.gd), dessinés à l'écran au-dessus du monde, quand la caméra regarde
## la jungle. Tout est accroché au monde : gouttes obliques poussées par le vent (aucune sur la roche de la
## montagne), éclaboussures au sol, ronds sur la rivière, voile de brume, flash blanc des éclairs d'orage.

const DROP := Color(0.72, 0.80, 0.88, 0.38)
const SPLASH := Color(0.80, 0.86, 0.92, 0.45)
const MAX_DROPS := 420
const MIST := Color(0.80, 0.86, 0.88)

var world: World
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Part de l'écran sur la jungle (0 quand tout l'écran est sous la montagne, 1 dès que le bas en sort).
func outdoors() -> float:
	if world == null or world.camera == null:
		return 0.0
	var size := get_viewport_rect().size
	var g: Vector2 = world.camera.ground_from_screen(Vector2(size.x * 0.5, size.y))
	return clampf((g.y - CaveShape.mountain_edge(g.x) + 2.0) / 6.0, 0.0, 1.0)


func _draw() -> void:
	var out := outdoors()
	if out <= 0.0:
		return
	var cam: WorldCamera = world.camera
	var size := get_viewport_rect().size
	# Défilement du monde à l'écran : la pluie et la brume restent accrochées au sol quand la caméra bouge.
	var scroll: Vector2 = cam.project(0.0, 0.0, 0.0)
	var river: River = world.terrain_state.river if world.terrain_state else null
	var mist := Weather.mist() * out
	if mist > 0.01:
		_mist(cam, size, scroll, mist)
	var rain := Weather.rain() * out
	if rain > 0.01:
		var n := int(MAX_DROPS * rain)
		var slant := 0.28 + Wind.at(0.0, 0.0, _t * 0.3) * 0.08
		for i in n:
			var hx := Rng.hash3(i, 0, 0x7a1)
			var hy := Rng.hash3(i, 1, 0x7a1)
			var speed := 900.0 + hx * 400.0
			var y := fposmod(hy * size.y + _t * speed + scroll.y, size.y + 40.0) - 20.0
			var x := fposmod(hx * size.x + y * slant + scroll.x, size.x)
			# Rien ne tombe sur la roche de la montagne.
			var g: Vector2 = cam.ground_from_screen(Vector2(x, y))
			if g.y < CaveShape.mountain_edge(g.x):
				continue
			var len := 10.0 + hy * 8.0
			draw_line(Vector2(x, y), Vector2(x - len * slant, y - len), DROP, 2.0)
		# Impacts : éclaboussures au sol, ronds qui s'élargissent sur l'eau.
		for i in int(n * 0.25):
			var life := fposmod(_t * 3.0 + Rng.hash3(i, 2, 0x5b1) * 3.0, 1.0)
			var slot := floori(_t * 3.0 + Rng.hash3(i, 2, 0x5b1) * 3.0)
			var p := Vector2(fposmod(Rng.hash3(i, slot, 0x5b2) * size.x + scroll.x, size.x), fposmod(Rng.hash3(i, slot, 0x5b3) * size.y + scroll.y, size.y))
			var g: Vector2 = cam.ground_from_screen(p)
			if g.y < CaveShape.mountain_edge(g.x):
				continue
			var c := SPLASH
			c.a *= 1.0 - life
			var r := 2.0 + life * 5.0
			if river != null and river.water_at(g.x, g.y):
				var rw := (2.0 + life * 7.0) * float(cam.px) * 0.5
				draw_rect(Rect2(p.x - rw, p.y - rw * 0.5, rw * 2.0, rw), c, false, 2.0)
				continue
			draw_line(p + Vector2(-r, 0), p + Vector2(-r * 0.4, -r * 0.5), c, 2.0)
			draw_line(p + Vector2(r, 0), p + Vector2(r * 0.4, -r * 0.5), c, 2.0)
	var flash := Weather.lightning(GameState.sim_time) * out
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.95, 1.0, 0.35 * flash))


## Brume : voile pâle sur la jungle (par colonnes, arrêté à la lisière de la montagne) et nappes plus
## denses qui dérivent lentement avec le vent, accrochées au monde.
func _mist(cam: WorldCamera, size: Vector2, scroll: Vector2, amount: float) -> void:
	var cols := 24
	var w := size.x / cols
	for k in cols:
		var x := (k + 0.5) * w
		var g: Vector2 = cam.ground_from_screen(Vector2(x, 0.0))
		var top: float = cam.project(g.x, 0.0, CaveShape.mountain_edge(g.x) + 2.0).y
		if top < size.y:
			var x0 := floorf(k * w)
			draw_rect(Rect2(x0, maxf(0.0, top), floorf((k + 1) * w) - x0, size.y - maxf(0.0, top)), Color(MIST.r, MIST.g, MIST.b, 0.3 * amount))
	var band := 96.0 * float(cam.px)
	var drift := _t * 6.0 * float(cam.px)
	for j in range(-1, int(size.y / band) + 2):
		for i in range(-1, int(size.x / (band * 3.0)) + 2):
			var ci := i - floori((scroll.x + drift) / (band * 3.0))
			var cj := j - floori(scroll.y / band)
			var h := Rng.hash3(ci, cj, 0x3b12)
			if h < 0.45:
				continue
			var p := Vector2(i * band * 3.0 + fposmod(scroll.x + drift, band * 3.0) + h * band, j * band + fposmod(scroll.y, band))
			var g: Vector2 = cam.ground_from_screen(p)
			if g.y < CaveShape.mountain_edge(g.x) + 6.0:
				continue
			for q in 3:
				draw_rect(Rect2(p.x - band * (1.3 - q * 0.3), p.y - band * (0.16 - q * 0.04), band * (2.6 - q * 0.6), band * (0.32 - q * 0.08)), Color(MIST.r, MIST.g, MIST.b, 0.07 * amount))
