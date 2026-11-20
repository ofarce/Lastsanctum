class_name ObjectivePanel
extends Control
## Panneau d'objectif en haut à gauche, sous la carte de vague : proposition 3 « Rapport de l'Ingénieur »
## (planches/objectif-propositions.html). Portrait de l'Ingénieur en médaillon, nom de la quête en surtitre,
## réplique en italique tapée lettre à lettre, puis, en cyan (technologie exilée), soit l'objectif et une
## jauge segmentée, soit une liste d'objectifs indépendants à cocher.
##
## Le HUD appelle push() à chaque mise à jour avec l'objectif courant (Quests.objective()) :
##   {id, quest, quote, done_quote, label, value, step, progress (0..1), items [{label, done}], soon, done}
## Quand l'identifiant change ou que l'objectif est marqué « done », le panneau joue l'état accompli
## (réplique de conclusion, éclat cyan), le garde DONE_HOLD secondes, sort, puis entre le suivant.
## « soon » : quête annoncée mais pas encore jouable (panneau grisé, « Bientôt ! »).
## « interrupt » : objectif prioritaire ; l'objectif affiché sort sans jouer son état accompli.

const WIDTH := 340.0
## Hauteur avec une seule ligne d'objectif ; la liste ajoute ROW_H par objectif.
const HEIGHT := 100.0
const ROW_Y := 66.0
const ROW_H := 18.0
const PORTRAIT := "res://assets/baked/hud/portraits/engineer.png"
const CYAN := Color("#5ce8ff")
const CYAN_PALE := Color("#c8fbff")
const CYAN_DIM := Color("#12596b")
const GREY := Color("#8d8a7c")
const SEGMENTS := 12
const IN_TIME := 0.45
const OUT_TIME := 0.45
const DONE_HOLD := 3.2
## Vitesse de frappe de la réplique (caractères par seconde).
const TYPE_RATE := 42.0
const X0 := 81.0
const INNER := WIDTH - X0 - 14.0

var _portrait := TextureRect.new()
var _eyebrow := HudStyle.label(10, HudStyle.MUTED, HudStyle.spaced(2))
var _step := HudStyle.label(10, HudStyle.MUTED, HudStyle.spaced(1))
var _quote := HudStyle.label(12, Color("#ddcfaf"), HudStyle.italic())
var _readout := HudStyle.label(12, CYAN)
var _value := HudStyle.label(11, CYAN, HudStyle.spaced(1))
var _rows: Array[Label] = []

## Objectif affiché, dernier objectif reçu, phase (hidden, in, run, done, out) et temps dans la phase.
var _cur := {}
var _latest := {}
var _phase := "hidden"
var _t := 0.0
var _type_t := 0.0
var _flash := 0.0
var _progress := 0.0
var _items: Array = []
## Décalage vertical du bas du panneau quand la réplique occupe une troisième ligne.
var _dy := 0.0
## Décalage d'entrée/sortie appliqué au dessin et aux enfants.
var _shift := Vector2.ZERO
var _last_shift := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(WIDTH, HEIGHT)
	visible = false
	_portrait.texture = load(PORTRAIT)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.position = Vector2(12, 12)
	_portrait.size = Vector2(56, 56)
	add_child(_portrait)
	_eyebrow.position = Vector2(X0, 8)
	_eyebrow.size = Vector2(INNER - 50.0, 16)
	_eyebrow.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_step.position = Vector2(X0 + INNER - 60.0, 8)
	_step.size = Vector2(60, 16)
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quote.position = Vector2(X0, 25)
	_quote.size = Vector2(INNER, 52)
	_quote.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote.max_lines_visible = 3
	_quote.add_theme_constant_override("line_spacing", -2)
	_readout.position = Vector2(X0, 63)
	_readout.size = Vector2(INNER, 18)
	_readout.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_value.position = Vector2(X0 + INNER - 80.0, 63)
	_value.size = Vector2(80, 18)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for l: Label in [_readout, _value]:
		l.add_theme_color_override("font_shadow_color", Color(CYAN, 0.18))
		l.add_theme_constant_override("shadow_outline_size", 3)
	for n: Control in [_eyebrow, _step, _quote, _readout, _value]:
		add_child(n)


## Objectif courant, envoyé à chaque mise à jour du HUD ({} : aucun objectif).
func push(data: Dictionary) -> void:
	_latest = data
	match _phase:
		"hidden":
			if not data.is_empty():
				_enter(data)
		"in", "run":
			if not data.is_empty() and data["id"] != _cur["id"] and data.get("interrupt", false):
				# Objectif prioritaire (premier boss) : la quête affichée sort sans être validée.
				_phase = "out"
				_t = 0.0
			elif data.is_empty() or data["id"] != _cur["id"]:
				_complete()
			else:
				var quote_changed: bool = data.get("quote", "") != _cur.get("quote", "")
				_cur = data
				if data.get("done", false):
					_complete()
				else:
					if quote_changed:
						_type(String(data.get("quote", "")))
					_show_values()


## Nouvelle partie : le panneau disparaît sans jouer d'état accompli.
func reset() -> void:
	_cur = {}
	_latest = {}
	_phase = "hidden"
	visible = false


## Identifiant de l'objectif affiché ("" : aucun) et phase d'animation (tests, captures).
func shown_id() -> String:
	return "" if _phase == "hidden" else String(_cur.get("id", ""))


func phase() -> String:
	return _phase


func _enter(data: Dictionary) -> void:
	_cur = data
	_phase = "in"
	_t = 0.0
	_flash = 0.0
	_progress = float(data.get("progress", 0.0))
	var soon: bool = data.get("soon", false)
	_portrait.self_modulate = Color(0.55, 0.55, 0.55) if soon else Color.WHITE
	_quote.add_theme_color_override("font_color", Color("#a9a491") if soon else Color("#ddcfaf"))
	_type(String(data.get("quote", "")))
	_show_values()
	visible = true


func _complete() -> void:
	_phase = "done"
	_t = 0.0
	_flash = 1.0
	_progress = 1.0
	_type(String(_cur.get("done_quote", _cur.get("quote", ""))))
	for it: Dictionary in _items:
		it["done"] = true
	_apply_rows()
	if _items.is_empty():
		_set_readout(String(_cur.get("label", "")), "✓", CYAN_PALE)
	if _cur.has("step"):
		_step.text = "ACCOMPLI"
	queue_redraw()


func _type(text: String) -> void:
	_type_t = 0.0
	_quote.text = "« %s »" % text if not text.is_empty() else ""
	_quote.visible_characters = 0
	# La place de la réplique est réservée dès le début de la frappe : le panneau ne bouge plus ensuite.
	var lines := HudStyle.italic().get_multiline_string_size(_quote.text, HORIZONTAL_ALIGNMENT_LEFT, INNER, 12,
		-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y / HudStyle.italic().get_height(12)
	var dy := 15.0 if roundi(lines) > 2 else 0.0
	if dy != _dy:
		_dy = dy
		_relayout()


## Place la ligne de relevé et la liste sous la réplique, et ajuste la hauteur du panneau.
func _relayout() -> void:
	_readout.position.y = 63.0 + _dy + _last_shift.y
	_value.position.y = 63.0 + _dy + _last_shift.y
	_apply_rows()
	var h := (HEIGHT if _items.is_empty() else ROW_Y + _items.size() * ROW_H + 12.0) + _dy
	if size.y != h:
		size = Vector2(WIDTH, h)


func _show_values() -> void:
	var soon: bool = _cur.get("soon", false)
	_eyebrow.text = String(_cur.get("quest", "")).to_upper()
	_step.text = "" if soon else String(_cur.get("step", ""))
	_eyebrow.size.x = INNER - (HudStyle.text_width(_step.text, 10, HudStyle.spaced(1)) + 10.0 if not _step.text.is_empty() else 0.0)
	_items = []
	for it: Dictionary in _cur.get("items", []):
		_items.append(it.duplicate())
	if _items.is_empty():
		_set_readout(String(_cur.get("label", "")), String(_cur.get("value", "")), GREY if soon else CYAN)
	_relayout()
	var p := clampf(float(_cur.get("progress", 0.0)), 0.0, 1.0)
	if p != _progress:
		_progress = p
	queue_redraw()


## Ligne de relevé : « ▸ objectif », valeur à droite ; police réduite si le libellé est trop long.
func _set_readout(text: String, value: String, color: Color) -> void:
	_readout.visible = true
	_value.visible = true
	_readout.text = "▸ " + text if not text.is_empty() else ""
	_value.text = value
	var room := INNER - (HudStyle.text_width(value, 11) + 10.0 if not value.is_empty() else 0.0)
	var px := 12
	while px > 10 and HudStyle.text_width(_readout.text, px) > room:
		px -= 1
	_readout.add_theme_font_size_override("font_size", px)
	_readout.size.x = room
	for l: Label in [_readout, _value]:
		l.add_theme_color_override("font_color", color)
		l.add_theme_color_override("font_shadow_color", Color(color, 0.0 if color == GREY else 0.18))


## Liste d'objectifs indépendants : une étiquette par ligne, les losanges sont dessinés dans _draw().
func _apply_rows() -> void:
	var list := not _items.is_empty()
	if list:
		_readout.visible = false
		_value.visible = false
	while _rows.size() < _items.size():
		var l := HudStyle.label(12, CYAN)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(l)
		l.position += _last_shift
		_rows.append(l)
	for i in _rows.size():
		var l := _rows[i]
		l.visible = i < _items.size()
		if not l.visible:
			continue
		var done: bool = _items[i]["done"]
		l.text = String(_items[i]["label"])
		l.position = Vector2(X0 + 16.0, ROW_Y + _dy + i * ROW_H) + _last_shift
		l.size = Vector2(INNER - 32.0, ROW_H)
		l.add_theme_color_override("font_color", Color("#8fb9bd") if done else Color("#ddd2b6"))
	queue_redraw()


func _process(delta: float) -> void:
	if _phase == "hidden":
		return
	_t += delta
	_type_t += delta
	var typed := int(maxf(0.0, _type_t - 0.15) * TYPE_RATE)
	_quote.visible_characters = -1 if typed >= _quote.get_total_character_count() else typed
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.6)
		queue_redraw()
	match _phase:
		"in":
			var k := 1.0 - pow(1.0 - clampf(_t / IN_TIME, 0.0, 1.0), 3.0)
			modulate.a = k
			_offset(Vector2((1.0 - k) * -18.0, 0.0))
			if _t >= IN_TIME:
				_phase = "run"
				_offset(Vector2.ZERO)
		"done":
			if _t >= DONE_HOLD:
				_phase = "out"
				_t = 0.0
		"out":
			var k := clampf(_t / OUT_TIME, 0.0, 1.0)
			modulate.a = 1.0 - k * k
			_offset(Vector2(0.0, -8.0 * k * k))
			if _t >= OUT_TIME:
				_offset(Vector2.ZERO)
				if not _latest.is_empty() and _latest["id"] != _cur["id"] and not _latest.get("done", false):
					_enter(_latest)
				else:
					_phase = "hidden"
					visible = false


## Décalage d'animation : les enfants et le dessin glissent, la position de mise en page reste fixe.
func _offset(v: Vector2) -> void:
	if v == _shift:
		return
	_shift = v
	for c in get_children():
		if c is Control:
			(c as Control).position += v - _last_shift
	_last_shift = v
	queue_redraw()


func _draw() -> void:
	draw_set_transform(_shift)
	var soon: bool = _cur.get("soon", false)
	var accent := GREY if soon else CYAN
	var r := Rect2(Vector2.ZERO, size)
	HudStyle.metal_panel(self, size)
	# Médaillon du portrait : fond, anneau sombre, liseré laiton (cyan pendant l'éclat d'objectif atteint).
	var pf := Rect2(11, 11, 58, 58)
	if _flash > 0.0:
		for i in 5:
			draw_rect(pf.grow(2.0 + i * 2.0), Color(CYAN, 0.08 * _flash))
	draw_rect(pf, Color("#152019"))
	HudStyle.ring(self, pf.grow(-1.0), 2.0, Color("#0c100f"))
	HudStyle.ring(self, pf, 1.0, SnesBanner.RIM_LO.lerp(CYAN, _flash))
	# Voyant « en ligne » de l'Ingénieur (éteint pour une quête à venir).
	var led := Rect2(pf.end.x - 5.0, pf.end.y - 5.0, 8, 8)
	if not soon:
		draw_rect(led.grow(2.0), Color(CYAN, 0.18))
	draw_rect(led, Color("#0a0a0c"))
	draw_rect(led.grow(-1.0), accent if not soon else Color("#4a4a44"))
	if not _items.is_empty():
		_draw_rows()
	elif not soon:
		_draw_gauge()
	draw_set_transform(Vector2.ZERO)


## Jauge segmentée sous la ligne de relevé.
func _draw_gauge() -> void:
	var gap := 2.0
	var sw := (INNER - gap * (SEGMENTS - 1)) / SEGMENTS
	var on := roundi(_progress * SEGMENTS)
	for i in SEGMENTS:
		var s := Rect2(X0 + i * (sw + gap), 85.0 + _dy, sw, 5.0)
		if i < on:
			draw_rect(s.grow(1.0), Color(CYAN, 0.25))
			draw_rect(s, CYAN_PALE)
			draw_rect(s.grow(-1.0), CYAN)
		else:
			draw_rect(s, CYAN_DIM)
			draw_rect(s.grow(-1.0), Color("#0f2a30"))


## Losange par objectif (vide, puis plein et cyan une fois validé) et coche en bout de ligne.
func _draw_rows() -> void:
	var y0 := ROW_Y + _dy
	draw_line(Vector2(X0, y0 - 2.0), Vector2(X0 + INNER, y0 - 2.0), Color(CYAN_DIM, 0.6), 1.0)
	for i in _items.size():
		var done: bool = _items[i]["done"]
		var c := Vector2(X0 + 5.0, y0 + i * ROW_H + ROW_H / 2.0)
		var d := 4.0
		var pts := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)])
		if done:
			draw_colored_polygon(pts, CYAN)
			var glow := pts.duplicate()
			glow.append(pts[0])
			draw_polyline(glow, Color(CYAN_PALE, 0.9), 1.0)
			var k := Vector2(X0 + INNER - 12.0, c.y)
			draw_polyline(PackedVector2Array([k + Vector2(0, 0), k + Vector2(3.5, 3.5), k + Vector2(10, -4)]), CYAN, 1.6)
		else:
			draw_colored_polygon(pts, Color("#0b100d"))
			pts.append(pts[0])
			draw_polyline(pts, CYAN_DIM.lerp(CYAN, 0.35), 1.0)
