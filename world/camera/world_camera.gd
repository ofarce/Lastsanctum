class_name WorldCamera
extends Node
## Caméra du prototype (73b410f : frame, PAN, wheel, clampCam dans galleries.js).
## - cam = (cam.x, cam.z) en unités de monde ; px = facteur de pixel entier (zoom) ;
## - clavier : ZQSD / WASD / flèches à 10 unités/s, sur les axes du monde (comme le JS) ;
## - glisser avec le bouton droit (seuil de 5 px) ; un clic droit sans glisser reste un ordre ;
## - molette : px ± 1, entre 1 et 6.
## La touche A ne sert qu'à la caméra ; Ctrl maintenu (Ctrl+A : tout sélectionner, décision D2) bloque le défilement.

signal view_changed

## clampCam : x ∈ [WORLD.x0 + 30, WORLD.x1 − 30], z ∈ [WORLD.z0 + 20, WORLD.z1 − 28] (galleries.js).
const CAM_MIN := Vector2(-202.0, -316.0)
const CAM_MAX := Vector2(202.0, 44.0)
## Position de départ (init(), Index.html).
const START := Vector2(0.0, -148.0)
const KEY_SPEED := 10.0
## Pas de simulation maximal du prototype (Index.html:359).
const MAX_DT := 0.045
const DRAG_THRESHOLD := 5.0
const PX_MIN := 1
const PX_MAX := 6

var cam := START
var px := 1
## Désactivé pour les captures de validation.
var input_enabled := true

var _pan_on := false
var _pan_moved := false
var _pan_last := Vector2.ZERO
## Touches appuyées avec Ctrl ou Cmd (Ctrl+A, D2) : tant que l'une est maintenue, pas de défilement.
var _chords := {}


func _ready() -> void:
	px = Proj.initial_px(screen_size().x)


func screen_size() -> Vector2:
	var viewport := get_viewport()
	if viewport:
		return viewport.get_visible_rect().size
	# Hors de l'arbre de scène (tests) : taille de fenêtre du projet.
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))


func reset() -> void:
	cam = START
	_pan_on = false
	_pan_moved = false
	view_changed.emit()


func set_view(new_cam: Vector2, new_px: int) -> void:
	cam = clamp_cam(new_cam)
	px = clampi(new_px, PX_MIN, PX_MAX)
	view_changed.emit()


static func clamp_cam(c: Vector2) -> Vector2:
	return c.clamp(CAM_MIN, CAM_MAX)


func project(x: float, y: float, z: float) -> Vector2:
	return Proj.project(x, y, z, cam, px, screen_size())


func ground_from_screen(p: Vector2) -> Vector2:
	return Proj.ground_from_screen(p, cam, px, screen_size())


## Vrai si le dernier appui droit a servi à déplacer la caméra : le clic droit ne doit alors
## pas être interprété comme un ordre (contextmenu, Index.html:357). Remet l'indicateur à zéro.
func consume_drag() -> bool:
	var moved := _pan_moved
	_pan_moved = false
	return moved


func _process(delta: float) -> void:
	if not input_enabled:
		return
	# Ctrl maintenu ou raccourci avec Ctrl en cours (Ctrl+A : tout sélectionner, D2) : pas de défilement.
	if not _chords.is_empty() or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		return
	var dx := Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left")
	var dz := Input.get_action_strength("cam_down") - Input.get_action_strength("cam_up")
	if dx != 0.0 or dz != 0.0:
		var step := KEY_SPEED * minf(delta, MAX_DT)
		cam = clamp_cam(cam + Vector2(signf(dx), signf(dz)) * step)
		view_changed.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.pressed and (event.ctrl_pressed or event.meta_pressed):
			_chords[event.keycode] = true
		elif not event.pressed:
			_chords.erase(event.keycode)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("zoom_in"):
		set_view(cam, px + 1)
	elif event.is_action_pressed("zoom_out"):
		set_view(cam, px - 1)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_pan_on = true
			_pan_moved = false
			_pan_last = event.position
		else:
			_pan_on = false
	elif event is InputEventMouseMotion and _pan_on and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		if not _pan_moved and event.position.distance_to(_pan_last) < DRAG_THRESHOLD:
			return
		_pan_moved = true
		var a := ground_from_screen(_pan_last)
		var b := ground_from_screen(event.position)
		cam = clamp_cam(cam + a - b)
		_pan_last = event.position
		view_changed.emit()
