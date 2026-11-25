class_name QuarterCard
extends CanvasLayer
## Carton d'entrée de quartier (sim/quarter_marks.gd, GameState.quarter_card) : en haut de l'écran, nom espacé entre
## deux filets à la couleur du quartier, ligne de rappel au premier passage ; apparaît et s'efface en fondu.

const FADE := 0.35
var _draw := Control.new()


func _ready() -> void:
	layer = 6
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_paint)
	add_child(_draw)


func _process(_delta: float) -> void:
	_draw.queue_redraw()


func _paint() -> void:
	var c: Dictionary = GameState.quarter_card
	if c.is_empty():
		return
	var t := GameState.sim_time - float(c["at"])
	var dur := float(c["dur"])
	if t < 0.0 or t > dur:
		return
	var a := clampf(minf(t / FADE, (dur - t) / FADE), 0.0, 1.0)
	var font := HudStyle.font()
	var col: Color = c["color"]
	var title: String = c["name"]
	var sub: String = c.get("sub", "")
	var size := 34
	var spaced := " ".join(title.split(""))
	var tw := font.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x if sub != "" else 0.0
	var w := maxf(tw, sw) + 56.0
	var h := 58.0 if sub == "" else 82.0
	var x := (_draw.size.x - w) / 2.0
	var y := 118.0
	_draw.draw_rect(Rect2(x, y, w, h), Color(0.043, 0.039, 0.059, 0.78 * a))
	_draw.draw_rect(Rect2(x, y, w, 2.0), Color(col, a))
	_draw.draw_rect(Rect2(x, y + h - 2.0, w, 2.0), Color(col, a))
	_draw.draw_string(font, Vector2((_draw.size.x - tw) / 2.0 + 2.0, y + 42.0), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * a))
	_draw.draw_string(font, Vector2((_draw.size.x - tw) / 2.0, y + 40.0), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.95, 0.93, 0.89, a))
	if sub != "":
		_draw.draw_string(font, Vector2((_draw.size.x - sw) / 2.0, y + 68.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col, a))
