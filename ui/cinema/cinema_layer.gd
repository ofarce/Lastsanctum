class_name CinemaLayer
extends CanvasLayer
## Cadrage des cinématiques de la séquence d'ouverture (sim/opening.gd) : barres noires en haut et en bas,
## HUD masqué, commandes coupées, carton de jour encadré (9.3), flash plein écran, caméra pilotée
## (plans extérieurs) puis rendue au joueur sur l'Ingénieur.

const BAR := 0.107  # hauteur de chaque barre, en fraction de l'écran
const SERIF := preload("res://assets/fonts/NotoSerif-Regular.ttf")
const INK := Color("#ece5d2")

var simulation: Simulation
var world: World
var hud: CanvasLayer
var _draw_node := Control.new()
var _was_cinema := false
var _saved_px := 3
var _stage := ""
var _shake_seed := 0


func _ready() -> void:
	layer = 40
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_paint)
	add_child(_draw_node)


func _process(delta: float) -> void:
	var on := Opening.cinematic()
	if on != _was_cinema:
		_was_cinema = on
		if hud:
			hud.visible = not on
		if world:
			world.camera.input_enabled = not on
			if on:
				_saved_px = world.camera.px
				_stage = GameState.opening_stage
			else:
				# Fin de l'arrivée ou de l'intro de la capsule : on garde le zoom de la cinématique.
				if _stage in ["arrival", "boot"]:
					_saved_px = world.camera.px
				_back_to_engineer()
	if on and world:
		var target := Opening.camera()
		if not target.is_empty():
			var cam := world.camera
			var to: Vector2 = target["cam"]
			cam.set_view(cam.cam + (to - cam.cam) * (1.0 - exp(-3.0 * delta)), target["px"])
		var sh := Opening.shake()
		if sh > 0.0:
			_shake_seed += 1
			var o := Vector2(randf() - 0.5, randf() - 0.5) * 2.0 * sh / Proj.K
			world.camera.set_view(world.camera.cam + o, world.camera.px)
	_draw_node.queue_redraw()


func _back_to_engineer() -> void:
	for u in GameState.units:
		if u.role == "engineer" and u.alive():
			world.camera.set_view(u.pos(), _saved_px if _saved_px >= 2 else 3)
			return


func _paint() -> void:
	var size := _draw_node.size
	var fl: Array = Opening.flash()
	if fl[0] > 0.0:
		_draw_node.draw_rect(Rect2(Vector2.ZERO, size), Color(fl[1], fl[0]))
	var k := Opening.bars()
	if k > 0.0:
		k = k * k * (3.0 - 2.0 * k)
		var h := roundf(size.y * BAR * k)
		_draw_node.draw_rect(Rect2(0, 0, size.x, h), Color.BLACK)
		_draw_node.draw_rect(Rect2(0, size.y - h, size.x, h), Color.BLACK)
	var c: Array = Opening.card()
	if not c.is_empty():
		var a: float = c[1]
		var fs := roundi(size.y * 0.075)
		var text: String = c[0]
		var tw := SERIF.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := Vector2((size.x - tw) / 2.0, size.y * 0.5 + fs * 0.3)
		_draw_node.draw_string(SERIF, base + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5 * a))
		_draw_node.draw_string(SERIF, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, a))
		# Deux filets qui s'étirent depuis le carton.
		var w := size.x * 0.2 * a
		var y := roundf(size.y * 0.5 - fs * 0.05)
		_draw_node.draw_rect(Rect2(size.x / 2.0 - tw / 2.0 - 24 - w, y, w, 1), Color(INK, a))
		_draw_node.draw_rect(Rect2(size.x / 2.0 + tw / 2.0 + 24, y, w, 1), Color(INK, a))
