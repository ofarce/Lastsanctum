class_name Terrain
extends Node2D
## Sol du monde : 16 blocs de 1024² issus du baker (buildPixelWorld, 73b410f), chargés en `Image`
## modifiables. Le creusement et la révélation des galeries (étape 3) repeignent des cases de 32×32 px
## dans ces images, puis mettent à jour la texture du bloc concerné.
## Les positions sont en pixels natifs, sous le nœud World mis à l'échelle ×PX ; le matériau
## d'alignement (pixel_snap) est hérité du parent.

const BAKED := "res://assets/baked/"

var width := 0
var height := 0
## Pixel du sol où se trouve l'origine du monde (0, 0, 0).
var origin := Vector2i.ZERO
var chunk := 1024
var _images: Array[Image] = []
var _textures: Array[ImageTexture] = []
var _cols := 0


func build() -> void:
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BAKED + "manifest.json"))["world"]["ground"]
	width = int(g["width"])
	height = int(g["height"])
	origin = Vector2i(int(g["gx0"]), int(g["gy0"]))
	chunk = int(g["chunk"])
	_cols = int(g["cols"])
	for child in get_children():
		child.free()
	_images.clear()
	_textures.clear()
	for r in int(g["rows"]):
		for c in _cols:
			var image: Image = (load(BAKED + "world/ground/ground_r%d_c%d.png" % [r, c]) as Texture2D).get_image()
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			var texture := ImageTexture.create_from_image(image)
			_images.append(image)
			_textures.append(texture)
			var s := Sprite2D.new()
			s.name = "Ground_r%d_c%d" % [r, c]
			s.texture = texture
			s.centered = false
			s.position = Vector2(c * chunk - origin.x, r * chunk - origin.y)
			s.use_parent_material = true
			add_child(s)


## Copie `src` (opaque) dans le sol, coin haut-gauche au pixel (sx, sy) du sol ; gère les blocs voisins.
func blit(src: Image, sx: int, sy: int) -> void:
	_for_chunks(Rect2i(sx, sy, src.get_width(), src.get_height()), func(img: Image, local: Rect2i, from: Vector2i) -> void:
		img.blit_rect(src, Rect2i(local.position + from - Vector2i(sx, sy), local.size), local.position))


## Assombrit un rectangle du sol comme un fillRect('#0008') du canvas : canal × (255 − 136) / 255, arrondi.
func darken(rect: Rect2i) -> void:
	_for_chunks(rect, func(img: Image, local: Rect2i, _from: Vector2i) -> void:
		for y in range(local.position.y, local.end.y):
			for x in range(local.position.x, local.end.x):
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color8(_band(c.r8), _band(c.g8), _band(c.b8), c.a8)))


static func _band(v: int) -> int:
	return roundi(v * 119.0 / 255.0)


## Met à jour les textures des blocs modifiés depuis le dernier appel.
func flush() -> void:
	for k: int in _dirty:
		_textures[k].update(_images[k])
	_dirty.clear()


var _dirty := {}


## Appelle fn(image du bloc, rectangle local dans le bloc, origine du bloc en pixels du sol) pour chaque
## bloc touché par `rect` (pixels du sol).
func _for_chunks(rect: Rect2i, fn: Callable) -> void:
	var c0 := maxi(0, rect.position.x / chunk)
	var c1 := mini(_cols - 1, (rect.end.x - 1) / chunk)
	var r0 := maxi(0, rect.position.y / chunk)
	var r1 := mini(_images.size() / _cols - 1, (rect.end.y - 1) / chunk)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var origin_px := Vector2i(c * chunk, r * chunk)
			var inter := rect.intersection(Rect2i(origin_px, Vector2i(chunk, chunk)))
			if inter.size.x <= 0 or inter.size.y <= 0:
				continue
			var k := r * _cols + c
			fn.call(_images[k], Rect2i(inter.position - origin_px, inter.size), origin_px)
			_dirty[k] = true


## Couleur du sol au pixel (px, py) de l'image complète (coordonnées du sol, pas du monde).
func get_ground_pixel(px: int, py: int) -> Color:
	if px < 0 or py < 0 or px >= width or py >= height:
		return Color(0, 0, 0, 0)
	return _images[(py / chunk) * _cols + px / chunk].get_pixel(px % chunk, py % chunk)
