class_name FlameView
extends Node2D
## Flamme d'un brasero ou d'un cierge du Temple, dessinée pixel par pixel au-dessus de son sprite
## (enfant du sprite, origine au pied de l'objet). Ne se redessine que visible et allumée.

const FIRE := [Color8(216, 101, 28), Color8(240, 162, 58), Color8(255, 224, 138)]

var candle := false
var seed := 0.0
## Renvoie vrai quand la flamme brûle.
var burning: Callable


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _px(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0), c)


func _draw() -> void:
	if burning.is_valid() and not burning.call():
		return
	var t := GameState.sim_time
	if candle:
		_px(0, -4, FIRE[1])
		_px(0, -5 if sin(t * 8.0 + seed) > 0.3 else -4, FIRE[2])
		return
	for k in 3:
		var fx := (k - 1) * 2.6
		var fh := 5.0 + 2.5 * sin(t * 9.0 + k * 2.1 + seed) + 2.0 * Rng.hash3(floori(t * 10.0), k, int(seed))
		for j in ceili(fh):
			var w := roundi((1.0 - j / fh) * 1.5)
			var o := roundf(sin(t * 7.0 + j * 0.8 + k) * 0.7)
			var c: Color = FIRE[2] if j < fh * 0.3 else (FIRE[1] if j < fh * 0.65 else FIRE[0])
			for i in range(-w, w + 1):
				_px(fx + i + o, -11.0 - j, c)
	for k in 3:
		var u := fmod(t * 0.8 + Rng.hash3(k, 3, int(seed)), 1.0)
		_px((Rng.hash3(k, 7, int(seed)) - 0.5) * 8.0 + sin(t * 3.0 + k) * 2.0, -14.0 - u * 16.0, Color(FIRE[1], 1.0 - u))
