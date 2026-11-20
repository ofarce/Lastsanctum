class_name DialogueBubble
extends Control
## Bulle de dialogue reliée à la tête d'un personnage (dialogue.js et dialogue.css, 73b410f).
## Seul le mode compact est utilisé par le prototype (accueil de l'Ingénieur) : 240 px de large,
## texte de 13 px écrit lettre par lettre (24 ms par signe), fermeture automatique après
## longueur × 0,024 s + 3,5 s. Le mode complet (nom, choix, boutons) n'a aucun appel dans 73b410f.
## Entrée : affiche tout le texte puis passe à la suite ; Échap : ferme.
## Depuis le 2026-11-19 : affichée comme bannière 16 bits en haut de l'écran (SnesBanner), « Nom : texte »,
## au lieu d'une bulle reliée à la tête.

const CHAR_TIME := 0.024
const WIDTH := 240.0
const PAD := Vector2(11, 8)
const MARGIN := 12.0

var camera: WorldCamera
var dialogue: Dictionary = {}
var index := 0
var elapsed := 0.0
var _text := SnesBanner.label()
## Un blip « ui_texte » tous les TEXT_BLIP caractères affichés.
const TEXT_BLIP := 4
var _blips := 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_text)


func active() -> bool:
	return not dialogue.is_empty()


## showCharacterDialogue.
func show_dialogue(d: Dictionary) -> void:
	dialogue = d
	index = 0
	_render_line()
	visible = true
	Sfx.play("ui_banniere")
	_position()


## greetEngineer.
func greet_engineer(speaker: Unit) -> void:
	show_dialogue({"speaker": speaker, "name": "Ingénieur Exilé", "role": "engineer", "compact": true,
		"lines": ["Ah. elle est là. Au travail."]})


func _render_line() -> void:
	elapsed = 0.0
	_blips = 0
	_text.text = _prefix() + (line() if dialogue.get("any_button", false) else "")


## « Nom : » devant la réplique (bannière 16 bits).
func _prefix() -> String:
	var n := String(dialogue.get("name", ""))
	return n + " : " if n != "" else ""


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
	var count := line().length() if dialogue.get("any_button", false) or is_inf(elapsed) else floori(elapsed / CHAR_TIME)
	# Blip de défilement tous les TEXT_BLIP caractères (pas quand la réplique s'affiche d'un coup).
	var blips := floori(float(count) / TEXT_BLIP)
	if count < line().length() and blips > _blips:
		Sfx.play("ui_texte")
	_blips = blips
	_text.text = _prefix() + line().left(count)
	_position()


## advanceCharacterDialogue.
func advance() -> void:
	if not active():
		return
	if not dialogue.get("any_button", false) and _text.text != _prefix() + line():
		elapsed = INF
		tick(0.0)
		return
	if index + 1 < dialogue["lines"].size():
		index += 1
		_render_line()
		_position()
	else:
		close()


func close() -> void:
	dialogue = {}
	visible = false


## Bannière en haut de l'écran, centrée ; elle grandit avec le texte déjà écrit.
func _position() -> void:
	var u: Unit = dialogue.get("speaker")
	if u == null or not u.alive():
		close()
		return
	var view := get_viewport_rect().size
	var w := SnesBanner.width(view)
	var h := SnesBanner.height(_text.text if _text.text != "" else " ", w)
	size = Vector2(w, h)
	position = Vector2(roundf((view.x - w) / 2.0), BossBar.top())
	_text.position = SnesBanner.PAD
	_text.size = size - 2.0 * SnesBanner.PAD
	modulate.a = 1.0
	queue_redraw()


func _draw() -> void:
	SnesBanner.paint(self, Rect2(Vector2.ZERO, size))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
