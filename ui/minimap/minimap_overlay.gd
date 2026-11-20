class_name MinimapOverlay
## Recherche « Minicarte » : TAB ou M affiche la minicarte en plein écran, opaque à 40 % (transparence
## 60 %), avec la position du joueur en point doré. Elle reprend l'image de la minicarte du HUD, dont la
## fenêtre suit la caméra (donc le joueur incarné). Ne capte pas la souris : le jeu continue dessous.
extends Control

var opacity := 0.4
const SCREEN_VEIL := 0.25
const MAP_VEIL := 0.6
## Éclaircissement de la carte : ses teintes (jungle, roche, brouillard) sont trop sombres sur le voile.
const BRIGHTEN := 1.8
const GOLD := Color("#ffd24a")

var minimap: Minimap
var world: World


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


static func available() -> bool:
	return GameState.research_done.has("minimap")


func toggle() -> void:
	visible = not visible and available()
	queue_redraw()


func _process(_delta: float) -> void:
	if visible and not available():
		visible = false
	if visible:
		# Le conteneur du HUD n'a pas de taille propre : on couvre l'écran.
		position = Vector2.ZERO
		size = get_viewport_rect().size
		queue_redraw()


## Position du joueur : l'Exilé incarné, sinon le centre de la caméra.
func _player_pos() -> Vector2:
	var u: Variant = GameState.incarnated
	if u != null and is_instance_valid(u):
		return Vector2(u.x, u.z)
	return world.camera.cam if world != null else Vector2.ZERO


## Rectangle d'affichage : fenêtre du monde à ses proportions réelles, centrée, marge de 4 %.
func _map_rect() -> Rect2:
	var avail := size * 0.92
	var ratio := Minimap.win.size.x / Minimap.win.size.y
	var s := Vector2(avail.x, avail.x / ratio)
	if s.y > avail.y:
		s = Vector2(avail.y * ratio, avail.y)
	return Rect2((size - s) / 2.0, s)


func _draw() -> void:
	if minimap == null or minimap._tex == null or size.x < 32.0 or size.y < 32.0:
		return
	var r := _map_rect()
	# Voile sombre : léger sur l'écran, plus dense sous la carte, pour qu'elle se détache du jeu.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, SCREEN_VEIL))
	draw_rect(r, Color(0, 0, 0, MAP_VEIL))
	var fade := Color(BRIGHTEN, BRIGHTEN, BRIGHTEN, opacity)
	draw_texture_rect(minimap._tex, r, false, fade)
	HudStyle.ring(self, r.grow(2.0), 1.0, Color(HudStyle.GOLD, 0.8))
	# Point doré du joueur (halo sombre pour la lisibilité).
	var p := _player_pos()
	var q := r.position + Minimap.map_pt(p.x, p.y) / Vector2(Minimap.W, Minimap.H) * r.size
	if r.grow(-2.0).has_point(q):
		var t := float(Time.get_ticks_msec() % 1200) / 1200.0
		draw_circle(q, 10.0 + 4.0 * t, Color(GOLD, 0.35 * (1.0 - t)))
		draw_circle(q, 7.0, Color(0, 0, 0, 0.7))
		draw_circle(q, 5.0, GOLD)
