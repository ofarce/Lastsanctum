class_name ActionButton
extends BaseButton
## Bouton du panneau d'ordres (.action, hud.css, et style en ligne d'Index.html, 73b410f) :
## icône de 18 px, libellé de 10 px sur deux lignes au plus, touche (kbd), recharge en haut à droite.
## États : normal, survolé ou actif (laiton éclairé), désactivé (gris).

var action: Dictionary = {}
var _icon := TextureRect.new()
var _label := HudStyle.label(10, HudStyle.IVORY)
## Le libellé est rogné par ce conteneur (overflow: hidden) plutôt que par le Label, qui masquerait
## toute ligne incomplète.
var _label_clip := Control.new()
var _kbd := HudStyle.label(9, HudStyle.IVORY)
var _cd := HudStyle.label(10, Color("#d8bf8d"))
var _icon_name := ""


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	add_child(_icon)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Coupure aux espaces seulement (un mot trop long déborde et est rogné, comme en CSS).
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_constant_override("line_spacing", -3)
	_label_clip.clip_contents = true
	_label_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_clip.add_child(_label)
	add_child(_label_clip)
	_kbd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_kbd)
	_cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_cd)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func set_action(a: Dictionary) -> void:
	action = a
	disabled = a["disabled"]
	tooltip_text = a["title"] if a["title"] else a["label"]
	if _icon_name != a["icon"]:
		_icon_name = a["icon"]
		_icon.texture = HudStyle.icon(_icon_name, 18, 1.6)
	_label.text = a["label"]
	var k: String = a["key"]
	_kbd.text = "Espace" if k == " " else k.to_upper()
	_cd.text = a["cooldown"]
	_relayout()
	queue_redraw()


func _lit() -> bool:
	return not disabled and (action.get("active", false) or is_hovered())


func _relayout() -> void:
	# Colonne flexible centrée (bordure 1, marge 2) : icône 18, écart 1, libellé, écart 1, touche 13.
	# Le libellé (11 px par ligne, 2 lignes au plus) se rétrécit quand la place manque : dans la grille
	# de 2 rangées du prototype, il ne reste qu'environ 9,5 px, soit une ligne un peu rognée.
	var lines := clampi(_label.get_line_count(), 1, 2) if _label.text else 1
	var avail := size.y - 6.0 - 18.0 - 13.0 - 2.0
	var label_h := minf(11.0 * lines, maxf(0.0, avail))
	var kbd_w := maxf(19.0, HudStyle.text_width(_kbd.text, 9) + 8.0)
	var total := 18.0 + 1.0 + label_h + 1.0 + 13.0
	var top := (size.y - total) / 2.0
	_icon.position = Vector2((size.x - 18.0) / 2.0, top)
	_icon.size = Vector2(18, 18)
	_label_clip.position = Vector2(1.0, top + 19.0)
	_label_clip.size = Vector2(size.x - 2.0, label_h)
	_label.position = Vector2(0.0, -2.0)
	_label.size = Vector2(size.x - 2.0, 26.0)
	_kbd.position = Vector2((size.x - kbd_w) / 2.0, top + 19.0 + label_h + 1.0)
	_kbd.size = Vector2(kbd_w, 13.0)
	_cd.position = Vector2(size.x - 44.0, 2.0)
	_cd.size = Vector2(40.0, 12.0)
	var fg := Color("#7c7c6c") if disabled else (Color("#ffe5ac") if _lit() else HudStyle.IVORY)
	_label.add_theme_color_override("font_color", fg)
	_kbd.add_theme_color_override("font_color", fg)
	_icon.modulate = Color("#727263") if disabled else (Color("#ffe1a3") if _lit() else Color("#e9ce9e"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


func _draw() -> void:
	_relayout()
	var r := Rect2(Vector2.ZERO, size)
	if _lit():
		# radial-gradient(ellipse at 50% 30%, #77521999, #201e12 85%) ; anneau intérieur #c29148 ; halo.
		draw_rect(r, Color("#201e12"))
		var c := Vector2(size.x * 0.5, size.y * 0.3)
		for i in range(12, 0, -1):
			var t := float(i) / 12.0
			var rad := Vector2(size.x, size.y) * 0.85 * t
			var col := Color("#775219").lerp(Color("#201e12"), t)
			var pts := PackedVector2Array()
			for k in 32:
				var ang := TAU * k / 32.0
				var p := c + Vector2(cos(ang) * rad.x, sin(ang) * rad.y)
				pts.append(p.clamp(Vector2.ZERO, size))
			draw_colored_polygon(pts, Color(col, 0.6))
		HudStyle.ring(self, r.grow(-1.0), 2.0, Color("#c29148"))
		HudStyle.ring(self, r, 1.0, Color("#ffe0a0"))
	else:
		var a := Color("#24261f") if disabled else Color("#2d2b21")
		var b := Color("#101510") if disabled else Color("#121712")
		HudStyle.linear_gradient(self, r, 145.0, [[0.0, a], [0.65, b], [1.0, b]])
		HudStyle.ring(self, r.grow(-1.0), 3.0, Color("#131710"))
		HudStyle.ring(self, r, 1.0, Color("#565443") if disabled else Color("#aa8851"))
	# Cadre de la touche.
	var kr := Rect2(_kbd.position, _kbd.size)
	draw_rect(kr, Color("#10140d"))
	draw_rect(kr.grow(-0.5), Color("#4d4f40") if disabled else Color("#8c744b"), false, 1.0)


func _pressed() -> void:
	if not disabled and action.has("run"):
		(action["run"] as Callable).call()
