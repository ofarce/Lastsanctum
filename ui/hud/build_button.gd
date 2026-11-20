class_name BuildButton
extends BaseButton
## Grand carré du menu « Construire » (proposition B de planches/construire_5_propositions.html) :
## image du bâtiment, touche en bas à droite, liseré jaune au survol ou quand il est armé.

## 44 px à l'origine, + 50 % le 2026-11-21.
const SIZE := 66.0
static var _arts := {}

var action: Dictionary = {}
var _tex: Texture2D
var _kbd := HudStyle.label(10, HudStyle.MUTED)


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	_kbd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_kbd)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


## Image du bâtiment rognée à sa zone opaque (les images bakées ont beaucoup de marge transparente).
static func art(name: String) -> Texture2D:
	if not _arts.has(name):
		var t: Texture2D = load("res://assets/baked/buildings/%s_base.png" % name)
		var at := AtlasTexture.new()
		at.atlas = t
		at.region = Rect2(t.get_image().get_used_rect()) if t else Rect2()
		_arts[name] = at
	return _arts[name]


func set_action(a: Dictionary) -> void:
	action = a
	disabled = a["disabled"]
	tooltip_text = ""
	_tex = art(Catalog.BUILDINGS[a["build_type"]]["art"])
	_kbd.text = String(a["key"]).to_upper()
	var w := maxf(15.0, HudStyle.text_width(_kbd.text, 10) + 6.0)
	_kbd.position = Vector2(SIZE - w - 2.0, SIZE - 15.0)
	_kbd.size = Vector2(w, 13.0)
	queue_redraw()


func lit() -> bool:
	return is_hovered() or action.get("active", false)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("#14170fe8"))
	if _tex:
		var inner := r.grow(-3.0)
		var ts := _tex.get_size()
		var k := minf(inner.size.x / ts.x, inner.size.y / ts.y)
		var d := ts * k
		var mod := Color(0.4, 0.4, 0.38) if action.get("locked", false) else (Color(0.75, 0.75, 0.72) if disabled else Color.WHITE)
		draw_texture_rect(_tex, Rect2(inner.position + (inner.size - d) / 2.0, d), false, mod)
	if lit():
		HudStyle.ring(self, r, 2.0, Color("#e8c35a"))
		HudStyle.ring(self, r.grow(1.0), 1.0, Color(0, 0, 0, 0.8))
	else:
		HudStyle.ring(self, r, 1.0, Color("#565443") if disabled else HudStyle.GOLD)
	var kr := Rect2(_kbd.position, _kbd.size)
	draw_rect(kr, Color("#10140d"))
	draw_rect(kr.grow(-0.5), Color("#4d4f40"), false, 1.0)
	if action.get("locked", false):
		# Petit cadenas : anse + corps.
		draw_arc(Vector2(12, 10), 3.5, PI, TAU, 10, HudStyle.MUTED, 1.5, true)
		draw_rect(Rect2(7, 10, 10, 8), HudStyle.MUTED)


func _pressed() -> void:
	if not disabled and action.has("run"):
		Sfx.play("ui_clic")
		(action["run"] as Callable).call()
