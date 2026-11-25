class_name FlameView
extends Node2D
## Flamme d'un brasero ou d'un cierge du Temple, dessinée pixel par pixel au-dessus de son sprite
## (enfant du sprite, origine au pied de l'objet). Ne se redessine que visible et allumée.

const FIRE := [Color8(216, 101, 28), Color8(240, 162, 58), Color8(255, 224, 138)]

var candle := false
## Quartier du Temple en salles où brûle la flamme (« A », « B », « C ») ; "" ailleurs. Une fois les repères du quartier
## allumés (GameState.quarter_lit, sim/quarter_marks.gd), elle prend sa couleur (planche des repères d'entrée).
var quarter := ""
static var _fires := {}
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
	var fire: Array = FIRE
	if quarter != "" and GameState.quarter_lit.has(quarter):
		fire = _quarter_fire(quarter)
	if candle:
		_px(0, -4, fire[1])
		_px(0, -5 if sin(t * 8.0 + seed) > 0.3 else -4, fire[2])
		return
	for k in 3:
		var fx := (k - 1) * 2.6
		var fh := 5.0 + 2.5 * sin(t * 9.0 + k * 2.1 + seed) + 2.0 * Rng.hash3(floori(t * 10.0), k, int(seed))
		for j in ceili(fh):
			var w := roundi((1.0 - j / fh) * 1.5)
			var o := roundf(sin(t * 7.0 + j * 0.8 + k) * 0.7)
			var c: Color = fire[2] if j < fh * 0.3 else (fire[1] if j < fh * 0.65 else fire[0])
			for i in range(-w, w + 1):
				_px(fx + i + o, -11.0 - j, c)
	for k in 3:
		var u := fmod(t * 0.8 + Rng.hash3(k, 3, int(seed)), 1.0)
		_px((Rng.hash3(k, 7, int(seed)) - 0.5) * 8.0 + sin(t * 3.0 + k) * 2.0, -14.0 - u * 16.0, Color(fire[1], 1.0 - u))


## Trois tons (foncé, vif, cœur clair) de la couleur du quartier.
static func _quarter_fire(q: String) -> Array:
	if not _fires.has(q):
		var c: Color = QuarterMarks.COLOR[q]
		_fires[q] = [c.darkened(0.3), c, c.lightened(0.55)]
	return _fires[q]
