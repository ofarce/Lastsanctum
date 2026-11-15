class_name DialogueBubble
extends Control
## Bulle de dialogue reliée à la tête d'un personnage (dialogue.js et dialogue.css, 73b410f).
## Seul le mode compact est utilisé par le prototype (accueil de l'Ingénieur) : 240 px de large,
## texte de 13 px écrit lettre par lettre (24 ms par signe), fermeture automatique après
## longueur × 0,024 s + 3,5 s. Le mode complet (nom, choix, boutons) n'a aucun appel dans 73b410f.
## Entrée : affiche tout le texte puis passe à la suite ; Échap : ferme.

const CHAR_TIME := 0.024
const WIDTH := 240.0
const PAD := Vector2(11, 8)
const MARGIN := 12.0
const GAP := 14.0
const BG := Color("#111c18f7")
const TAIL_BG := Color("#111c18")
const BORDER := Color("#a38b5a")

var camera: WorldCamera
var dialogue: Dictionary = {}
var index := 0
var elapsed := 0.0
var _text := HudStyle.label(13, Color("#e9e1ce"))
var _tail_x := WIDTH / 2.0
var _below := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_constant_override("line_spacing", 0)
	add_child(_text)


func active() -> bool:
	return not dialogue.is_empty()


## showCharacterDialogue.
func show_dialogue(d: Dictionary) -> void:
	dialogue = d
	index = 0
	_render_line()
	visible = true
	_position()


## greetEngineer.
func greet_engineer(speaker: Unit) -> void:
	show_dialogue({"speaker": speaker, "name": "Ingénieur Exilé", "role": "engineer", "compact": true,
		"lines": ["L’Ancre s’est éteinte. Je dois la réactiver : elle réveillera les gardes de l’entrée."]})


func _render_line() -> void:
	elapsed = 0.0
	_text.text = ""


func line() -> String:
	return dialogue["lines"][index]


## updateCharacterDialogue.
func tick(dt: float) -> void:
	if not active():
		return
	elapsed += dt
	if dialogue.get("compact", false) and elapsed > line().length() * CHAR_TIME + 3.5:
		close()
		return
	var count := line().length() if is_inf(elapsed) else floori(elapsed / CHAR_TIME)
	_text.text = line().left(count)
	_position()


## advanceCharacterDialogue.
func advance() -> void:
	if not active():
		return
	if _text.text != line():
		elapsed = INF
		tick(0.0)
		return
	if index + 1 < dialogue["lines"].size():
		index += 1
		_render_line()
	else:
		close()


func close() -> void:
	dialogue = {}
	visible = false


## positionCharacterDialogue : au-dessus de la tête (ou dessous, faute de place), pointe reliée à la tête.
func _position() -> void:
	var u: Unit = dialogue.get("speaker")
	if u == null or not u.alive() or u.hidden:
		close()
		return
	var view := get_viewport_rect().size
	var head := camera.project(u.x, 2.8, u.z)
	# Hauteur : texte déjà écrit (la bulle grandit vers le haut pendant l'écriture, comme dans le prototype).
	var f := HudStyle.font()
	var text_h := 0.0
	if not _text.text.is_empty():
		var lines := roundi(f.get_multiline_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 2.0 * PAD.x - 2.0, 13).y / f.get_height(13))
		text_h = 13.0 * 1.35 * maxi(1, lines)
	var h := text_h + 2.0 * PAD.y + 2.0
	size = Vector2(WIDTH, h)
	_text.position = PAD + Vector2.ONE
	_text.size = Vector2(WIDTH - 2.0 * PAD.x - 2.0, text_h + 2.0)
	var left := maxf(MARGIN, minf(view.x - WIDTH - MARGIN, head.x - WIDTH / 2.0))
	var above := head.y - GAP - h
	_below = above < MARGIN
	position = Vector2(left, head.y + GAP if _below else above)
	_tail_x = clampf(head.x - left, 18.0, WIDTH - 18.0)
	modulate.a = 0.0 if head.x < 0.0 or head.x > view.x or head.y < 0.0 or head.y > view.y else 1.0
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color("#00000077")
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 8)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	# Pointe : carré de 14 px tourné à 45°, centré 1 px sous le bord (bottom: -8px), bordé sur ses deux
	# côtés extérieurs ; sa moitié intérieure recouvre le liseré de la bulle. Au-dessus en mode « dessous ».
	var s := -1.0 if _below else 1.0
	var d := 7.0 * sqrt(2.0)
	var c := Vector2(_tail_x, (0.0 if _below else size.y) + s * 1.0)
	var left := c + Vector2(-d, 0)
	var right := c + Vector2(d, 0)
	var tip := c + Vector2(0, s * d)
	draw_colored_polygon(PackedVector2Array([left, c + Vector2(0, -s * d), right, tip]), TAIL_BG)
	draw_polyline(PackedVector2Array([left, tip, right]), BORDER, 1.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
