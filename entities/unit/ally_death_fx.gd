class_name AllyDeathFx
extends Node2D
## Mort d'un allié rendu par AdeptView (planches/unites-maj-propositions.html, piste A5), jouée à l'endroit où la vue
## vient d'être retirée : la Caserne tombe (atlas « death » du rôle, comme les soldats ennemis), reste au sol puis
## s'efface ; un esprit se dissipe (le Germe de l'autel à l'envers : trame vers la couleur unie du dieu, puis
## l'image s'élève et s'éteint par paliers).

## Caserne : temps au sol après la chute, puis fondu (s).
const HOLD := 2.5
const FADE := 1.0
## Esprit : trame (s), puis extinction (s) ; élévation totale (px natifs).
const SPIRIT_TINT := 0.45
const SPIRIT_OUT := 0.45
const SPIRIT_RISE := 8.0

var _tex: Texture2D
var _rects: Array[Rect2] = []
var _fps := 24.0
var _anchor := Vector2.ZERO
var _scale := 1.0
var _face := 1
var _spirit := false
var _t0 := 0.0
var _mat: ShaderMaterial
var _key := -1


## Reprend l'apparence de la vue (dernière image de repos pour un esprit). Faux si le rôle n'a rien à jouer.
func setup(view: AdeptView) -> bool:
	_spirit = view._spirit
	var mode := "idle" if _spirit else "death"
	if not view._frames.has(mode):
		return false
	_tex = view._frames[mode]["tex"]
	_rects = view._frames[mode]["rects"]
	_fps = float(view._fps.get(mode, 24.0))
	_anchor = Vector2(view._ax, view._ay)
	_scale = view._scale
	_face = view._face
	_t0 = GameState.sim_time
	position = view.position
	if _spirit:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://shaders/spirit_arrival.gdshader")
		_mat.set_shader_parameter("flat_color", Catalog.DEITY_GLOW.get(view.unit.role, Color.WHITE))
		material = _mat
	return true


func _process(_delta: float) -> void:
	var age := GameState.sim_time - _t0
	var total := SPIRIT_TINT + SPIRIT_OUT if _spirit else _rects.size() / _fps + HOLD + FADE
	if age < 0.0 or age >= total:
		queue_free()
		return
	# Redessin par paliers seulement (image de l'atlas, niveaux de trame et d'opacité).
	var key := floori(age * 24.0)
	if key != _key:
		_key = key
		queue_redraw()


func _draw() -> void:
	var age := GameState.sim_time - _t0
	if _spirit:
		var tint := clampf(ceilf(age / SPIRIT_TINT * 4.0) / 4.0, 0.0, 1.0)
		var out := clampf((age - SPIRIT_TINT) / SPIRIT_OUT, 0.0, 1.0)
		_mat.set_shader_parameter("tint", tint)
		draw_set_transform(Vector2(0.0, -roundf(SPIRIT_RISE * out)), 0.0, Vector2(_scale * _face, _scale))
		draw_texture_rect_region(_tex, Rect2(-_anchor, _rects[0].size), _rects[0], Color(1, 1, 1, 1.0 - floorf(out * 4.0) / 4.0))
		return
	var fall := _rects.size() / _fps
	var i := mini(_rects.size() - 1, floori(age * _fps))
	var alpha := clampf((fall + HOLD + FADE - age) / FADE, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_scale * _face, _scale))
	draw_texture_rect_region(_tex, Rect2(-_anchor, _rects[i].size), _rects[i], Color(1, 1, 1, alpha))
