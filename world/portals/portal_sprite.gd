class_name PortalSprite
extends Sprite2D
## Portail dessiné comme dans le prototype : image posée contre la paroi nord avec la matrice
## (k, k·0,5, 0, k) — cisaillement vertical — à partir de natP(x, 0, z), filtre « le plus proche ».
## Trois sortes (73b410f) : « exiles » (drawPortal : atlas de 554 images à 60 im/s depuis PORTAL.start),
## « deity » (drawDeityPortal : 12 images en boucle si actif, sinon l'image éteinte, k = 0,62),
## « evil » (drawEvilPortal : 12 images en boucle, k = 0,7).

var kind := "exiles"
var deity_id := ""
var frames := 1
var cols := 16
var frame_size := Vector2i(130, 112)
var active_texture: Texture2D
var off_texture: Texture2D


func setup(k: float, origin_offset: Vector2) -> void:
	centered = false
	region_enabled = true
	offset = -origin_offset
	transform = Transform2D(Vector2(k, k * 0.5), Vector2(0.0, k), Vector2.ZERO)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var t := GameState.sim_time
	var i := 0
	match kind:
		"exiles":
			i = mini(frames - 1, maxi(0, floori((t - GameState.portal_start) * 60.0)))
			texture = active_texture
		"deity":
			if GameState.deity_active.get(deity_id, false):
				texture = active_texture
				i = floori(t * 12.0 / (PI / 2.0)) % 12
			else:
				texture = off_texture
				i = 0
		"evil":
			texture = active_texture
			i = floori(t * 12.0 / (PI / 2.0)) % 12
	if texture == null:
		return
	region_rect = Rect2((i % cols) * frame_size.x, (i / cols) * frame_size.y, frame_size.x, frame_size.y)
