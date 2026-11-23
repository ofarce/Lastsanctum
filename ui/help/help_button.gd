class_name HelpButton
extends Control
## Bouton « ? » du bandeau du haut, à droite de la carte de vague : ouvre le codex d'aide (HelpPanel).
## Cadre Laiton des boutons de commande, touche F1 en pied, nom dans une bulle au survol, halo tant
## que l'aide n'a jamais été ouverte.

signal pressed

const SIZE := Vector2(56.0, 56.0)
const KEY := "F1"
const TITLE := "Aide"
const HINT := "Commandes, bases, mécaniques"

var _hover := false
var _pulse := false
var _was_pulse := true
var _was_open := false


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pulse = HelpPanel.never_opened()
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	PressFx.track(self, event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		_pulse = false
		pressed.emit()


func _process(_delta: float) -> void:
	if HelpPanel.open:
		_pulse = false
	# Seul le halo est animé ; sans lui, le bouton ne change qu'avec l'ouverture du codex ou le survol (signaux).
	if _pulse or _was_pulse or HelpPanel.open != _was_open:
		_was_pulse = _pulse
		_was_open = HelpPanel.open
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var f := HudStyle.font()
	var ink := HudStyle.GOLD_LIGHT
	var pressed := PressFx.down(self)
	PressFx.begin(self, r, pressed)
	if HelpPanel.open:
		# Codex ouvert : laiton plein, comme l'onglet choisi.
		HudStyle.linear_gradient(self, r, 180.0, [[0.0, HelpPanel.BRASS_TOP], [1.0, HelpPanel.BRASS_BOTTOM]])
		HudStyle.ring(self, r, 1.0, Color("#ffe5ac"))
		ink = HelpPanel.BRASS_INK
	elif _hover:
		HudStyle.linear_gradient(self, r, 180.0, [[0.0, Color("#3a3220")], [1.0, Color("#15170f")]])
		HudStyle.ring(self, r.grow(-1.0), 2.0, Color("#c29148"))
		HudStyle.ring(self, r, 1.0, Color("#ffe0a0"))
		ink = Color("#fff2cf")
	else:
		HudStyle.linear_gradient(self, r, 145.0, [[0.0, Color("#2d2b21")], [0.65, Color("#121712")], [1.0, Color("#121712")]])
		HudStyle.ring(self, r.grow(-1.0), 3.0, Color("#131710"))
		HudStyle.ring(self, r, 1.0, Color("#aa8851"))
	var qw := HudStyle.text_width("?", 27)
	draw_string(f, Vector2((size.x - qw) / 2.0, 31.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, ink)
	# Touche en pied.
	var kw := HudStyle.text_width(KEY, 10) + 9.0
	var kr := Rect2(roundf((size.x - kw) / 2.0), size.y - 18.0, kw, 14.0)
	draw_rect(kr, Color("#10140d") if not HelpPanel.open else HelpPanel.BRASS_INK)
	HudStyle.ring(self, kr, 1.0, Color("#8c744b") if not HelpPanel.open else HelpPanel.BRASS_INK)
	draw_string(f, kr.position + Vector2(4.5, 11.0), KEY, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HudStyle.MUTED if not HelpPanel.open else HudStyle.GOLD_LIGHT)
	PressFx.finish(self, r, pressed)
	if _pulse:
		# Halo : un filet clair qui s'écarte et s'efface, toutes les 1,6 s.
		var t := float(Time.get_ticks_msec() % 1600) / 1600.0
		HudStyle.ring(self, r.grow(2.0 + 9.0 * t), 2.0, Color(Color("#ffe5ac"), 0.95 * (1.0 - t)))
	if _hover and not HelpPanel.open:
		# Bulle sous le bouton (il est collé au bord haut de l'écran).
		var w := maxf(HudStyle.text_width(TITLE, 17), HudStyle.text_width(HINT, 13)) + 24.0
		var b := Rect2(0.0, size.y + 8.0, w, 50.0)
		draw_rect(b, Color("#10140df2"))
		HudStyle.ring(self, b, 2.0, Color("#c29148"))
		draw_string(f, b.position + Vector2(12.0, 21.0), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffe5ac"))
		draw_string(f, b.position + Vector2(12.0, 40.0), HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HudStyle.IVORY)
