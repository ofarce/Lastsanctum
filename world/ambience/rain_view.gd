class_name RainView
extends Control
## Pluie et éclairs (core/weather.gd), dessinés à l'écran au-dessus du monde, quand la caméra regarde
## la jungle (fondu à la lisière de la montagne). Gouttes obliques poussées par le vent, éclaboussures
## au sol, flash blanc des éclairs d'orage.

const DROP := Color(0.72, 0.80, 0.88, 0.38)
const SPLASH := Color(0.80, 0.86, 0.92, 0.45)
const MAX_DROPS := 420

var world: World
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Part de l'écran sur la jungle (0 dans la caverne, 1 dehors).
func outdoors() -> float:
	if world == null or world.camera == null:
		return 0.0
	var cam: Vector2 = world.camera.cam
	return clampf((cam.y - CaveShape.mountain_edge(cam.x) + 12.0) / 24.0, 0.0, 1.0)


func _draw() -> void:
	var rain := Weather.rain() * outdoors()
	var size := get_viewport_rect().size
	if rain > 0.01:
		var n := int(MAX_DROPS * rain)
		var slant := 0.28 + Wind.at(0.0, 0.0, _t * 0.3) * 0.08
		for i in n:
			var hx := Rng.hash3(i, 0, 0x7a1)
			var hy := Rng.hash3(i, 1, 0x7a1)
			var speed := 900.0 + hx * 400.0
			var y := fposmod(hy * size.y + _t * speed, size.y + 40.0) - 20.0
			var x := fposmod(hx * size.x + y * slant, size.x)
			var len := 10.0 + hy * 8.0
			draw_line(Vector2(x, y), Vector2(x - len * slant, y - len), DROP, 2.0)
		# Éclaboussures : petits arcs qui naissent et s'effacent.
		for i in int(n * 0.25):
			var life := fposmod(_t * 3.0 + Rng.hash3(i, 2, 0x5b1) * 3.0, 1.0)
			var slot := floori(_t * 3.0 + Rng.hash3(i, 2, 0x5b1) * 3.0)
			var p := Vector2(Rng.hash3(i, slot, 0x5b2) * size.x, Rng.hash3(i, slot, 0x5b3) * size.y)
			var c := SPLASH
			c.a *= 1.0 - life
			var r := 2.0 + life * 5.0
			draw_line(p + Vector2(-r, 0), p + Vector2(-r * 0.4, -r * 0.5), c, 2.0)
			draw_line(p + Vector2(r, 0), p + Vector2(r * 0.4, -r * 0.5), c, 2.0)
	var flash := Weather.lightning(GameState.sim_time) * outdoors()
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.95, 1.0, 0.35 * flash))
