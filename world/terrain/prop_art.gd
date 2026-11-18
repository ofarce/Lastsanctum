class_name PropArt
extends RefCounted
## Sprites des objets du chemin (RoadProps), peints au chargement. Ancre : bas au milieu.

const OUT := Color8(18, 16, 14)
const WOOD := [Color8(58, 40, 26), Color8(88, 62, 38), Color8(120, 88, 56), Color8(150, 116, 76)]
const IRON := [Color8(60, 64, 70), Color8(98, 104, 112), Color8(150, 156, 164)]
const STONE := [Color8(86, 84, 78), Color8(118, 114, 104), Color8(148, 142, 128)]
const MOSS := Color8(92, 116, 66)
const CLOTH := [Color8(196, 184, 150), Color8(230, 220, 190)]
const GOLD := Color8(206, 166, 72)
const RED := Color8(150, 50, 44)
const ASH := [Color8(40, 38, 36), Color8(70, 66, 60)]
const BONE := Color8(226, 218, 196)

static var _cache := {}


static func texture(k: String) -> Texture2D:
	if not _cache.has(k):
		_cache[k] = ImageTexture.create_from_image(paint(k))
	return _cache[k]


static func paint(k: String) -> Image:
	var img: Image
	match k:
		"sign": img = _sign()
		"cart": img = _cart()
		"wheel": img = _wheel()
		"crate": img = _crate()
		"barrel": img = _barrel()
		"milestone": img = _milestone()
		"banner": img = _banner()
		"helmet": img = _helmet()
		"spear": img = _spear()
		"stones": img = _stones()
		"basket": img = _basket()
		"skull": img = _skull()
		"palisade": img = _palisade(false)
		"palisade_broken": img = _palisade(true)
		"campfire": img = _campfire()
		"tent": img = _tent()
		_: img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_outline(img)
	return img


static func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(0, y), mini(img.get_height(), y + h)):
		for xx in range(maxi(0, x), mini(img.get_width(), x + w)):
			img.set_pixel(xx, yy, c)


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _line(img: Image, a: Vector2, b: Vector2, c: Color, w := 1) -> void:
	var n := ceili(a.distance_to(b)) + 1
	for i in n:
		var p := a.lerp(b, float(i) / maxf(1.0, n - 1))
		_rect(img, roundi(p.x), roundi(p.y), w, w, c)


static func _disc(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy < 1.0:
				img.set_pixel(x, y, c)


static func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edge: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and img.get_pixelv(q).a > 0.5 and img.get_pixelv(q) != OUT:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		img.set_pixelv(p, OUT)


## Poteau indicateur : deux flèches de bois, runes gravées.
static func _sign() -> Image:
	var img := _img(26, 34)
	_rect(img, 12, 6, 3, 27, WOOD[1])
	_rect(img, 12, 6, 1, 27, WOOD[2])
	for k in 2:
		var y := 8 + k * 9
		var left := k == 1
		var x0 := 3 if left else 12
		_rect(img, x0, y, 12, 5, WOOD[2])
		_rect(img, x0, y, 12, 1, WOOD[3])
		var tip := x0 - 2 if left else x0 + 12
		for t in 3:
			_rect(img, tip + (t if left else -t), y + t, 1, 5 - 2 * t, WOOD[2])
		for r in 3:
			_put(img, x0 + 3 + r * 3, y + 2, WOOD[0])
	_rect(img, 10, 31, 7, 2, STONE[0])
	return img


## Chariot renversé sur le flanc : plateau de planches, roue levée, ridelle cassée.
static func _cart() -> Image:
	var img := _img(44, 26)
	for k in 5:
		_rect(img, 4 + k * 7, 10, 6, 13, WOOD[1 + k % 2])
		_rect(img, 4 + k * 7, 10, 6, 1, WOOD[3])
	_rect(img, 2, 21, 38, 3, WOOD[0])
	_line(img, Vector2(38, 10), Vector2(43, 4), WOOD[1], 2)
	_disc(img, 13, 8, 7, 7, WOOD[1])
	_disc(img, 13, 8, 5, 5, Color(0, 0, 0, 0))
	for a in 6:
		var an := a * PI / 3.0
		_line(img, Vector2(13, 8), Vector2(13 + cos(an) * 5, 8 + sin(an) * 5), WOOD[2])
	_disc(img, 13, 8, 1.6, 1.6, IRON[1])
	_line(img, Vector2(26, 23), Vector2(32, 18), WOOD[3], 1)
	return img


static func _wheel() -> Image:
	var img := _img(18, 12)
	_disc(img, 9, 7, 8.5, 4.5, WOOD[1])
	_disc(img, 9, 7, 6.5, 3.2, Color(0, 0, 0, 0))
	for a in 4:
		var an := a * PI / 4.0
		_line(img, Vector2(9 - cos(an) * 6, 7 - sin(an) * 3), Vector2(9 + cos(an) * 6, 7 + sin(an) * 3), WOOD[2])
	_disc(img, 9, 7, 1.5, 1.2, IRON[1])
	_rect(img, 3, 4, 3, 2, Color(0, 0, 0, 0))
	return img


static func _crate() -> Image:
	var img := _img(14, 14)
	_rect(img, 1, 3, 12, 10, WOOD[1])
	_rect(img, 1, 1, 12, 3, WOOD[3])
	_line(img, Vector2(2, 4), Vector2(11, 12), WOOD[2])
	_line(img, Vector2(11, 4), Vector2(2, 12), WOOD[0])
	_rect(img, 9, 0, 4, 2, Color(0, 0, 0, 0))
	return img


static func _barrel() -> Image:
	var img := _img(12, 16)
	_rect(img, 2, 2, 8, 13, WOOD[2])
	_rect(img, 1, 4, 10, 9, WOOD[1])
	_rect(img, 1, 5, 10, 1, IRON[0])
	_rect(img, 1, 11, 10, 1, IRON[0])
	_rect(img, 3, 1, 6, 2, WOOD[3])
	return img


## Borne de pierre usée, moussue, chiffre gravé.
static func _milestone() -> Image:
	var img := _img(12, 18)
	_rect(img, 2, 4, 8, 13, STONE[1])
	_disc(img, 6, 5, 4, 3, STONE[2])
	_rect(img, 2, 10, 2, 7, STONE[0])
	_rect(img, 5, 8, 2, 4, STONE[0])
	for x in [2, 3, 8, 9]:
		_put(img, x, 15, MOSS)
		_put(img, x, 16, MOSS)
	_put(img, 4, 3, MOSS)
	return img


## Bannière du Credo déchirée sur sa hampe penchée.
static func _banner() -> Image:
	var img := _img(20, 36)
	_line(img, Vector2(6, 35), Vector2(9, 2), WOOD[0], 2)
	_rect(img, 9, 4, 9, 18, CLOTH[0])
	_rect(img, 9, 4, 9, 2, GOLD)
	_rect(img, 12, 9, 3, 6, GOLD)
	for k in 4:
		_rect(img, 10 + k * 2, 18 + (k % 2) * 3, 2, 6, Color(0, 0, 0, 0))
	_rect(img, 16, 11, 2, 3, Color(0, 0, 0, 0))
	return img


static func _helmet() -> Image:
	var img := _img(12, 9)
	_disc(img, 6, 6, 5.5, 5, IRON[1])
	_rect(img, 0, 6, 12, 3, Color(0, 0, 0, 0))
	_rect(img, 0, 6, 12, 2, IRON[0])
	_rect(img, 5, 1, 2, 5, GOLD)
	_put(img, 3, 3, IRON[2])
	return img


static func _spear() -> Image:
	var img := _img(14, 30)
	_line(img, Vector2(3, 29), Vector2(10, 4), WOOD[1])
	_line(img, Vector2(10, 4), Vector2(12, 0), IRON[2], 2)
	_rect(img, 1, 27, 5, 2, STONE[0])
	return img


static func _stones() -> Image:
	var img := _img(16, 9)
	_disc(img, 5, 6, 4.5, 3, STONE[1])
	_disc(img, 11, 6.5, 4, 2.5, STONE[0])
	_disc(img, 8, 3.5, 3, 2.2, STONE[2])
	_put(img, 4, 4, MOSS)
	return img


static func _basket() -> Image:
	var img := _img(12, 9)
	_rect(img, 1, 3, 10, 6, WOOD[2])
	for x in range(1, 11, 2):
		_rect(img, x, 3, 1, 6, WOOD[1])
	_rect(img, 0, 2, 12, 2, WOOD[3])
	_line(img, Vector2(2, 2), Vector2(6, -1), WOOD[1])
	return img


## Bâton planté coiffé d'un crâne d'animal.
static func _skull() -> Image:
	var img := _img(12, 26)
	_rect(img, 5, 6, 2, 20, WOOD[1])
	_disc(img, 6, 5, 4, 3.5, BONE)
	_put(img, 4, 5, OUT)
	_put(img, 7, 5, OUT)
	_line(img, Vector2(2, 3), Vector2(0, 0), BONE)
	_line(img, Vector2(10, 3), Vector2(11, 0), BONE)
	return img


## Pieux de palissade (debout, ou effondrés).
static func _palisade(broken: bool) -> Image:
	var img := _img(24, 22)
	for k in 4:
		var h := 18 - (k % 2) * 3
		if broken and k >= 2:
			_line(img, Vector2(4 + k * 5, 20), Vector2(4 + k * 5 + 9, 15 + k), WOOD[1], 3)
			continue
		_rect(img, 2 + k * 5, 21 - h, 4, h, WOOD[1 + k % 2])
		_rect(img, 3 + k * 5, 20 - h, 2, 1, WOOD[3])
	_rect(img, 1, 9, 21 if not broken else 10, 2, WOOD[0])
	return img


static func _campfire() -> Image:
	var img := _img(16, 9)
	for a in 8:
		var an := a * TAU / 8.0
		_rect(img, roundi(7 + cos(an) * 6), roundi(4 + sin(an) * 3), 2, 2, STONE[a % 3])
	_disc(img, 8, 5, 4, 2, ASH[0])
	_line(img, Vector2(5, 6), Vector2(11, 3), WOOD[0])
	_line(img, Vector2(5, 3), Vector2(11, 6), WOOD[0])
	_put(img, 8, 4, ASH[1])
	return img


## Tente effondrée : toile affaissée sur un mât cassé.
static func _tent() -> Image:
	var img := _img(30, 18)
	for x in 28:
		var top := 6 + roundi(absf(x - 9) * 0.55) + (2 if x > 16 else 0)
		_rect(img, 1 + x, top, 1, 17 - top, CLOTH[0] if x % 5 else CLOTH[1])
	_line(img, Vector2(10, 17), Vector2(10, 4), WOOD[1])
	_line(img, Vector2(10, 4), Vector2(15, 1), WOOD[1])
	_rect(img, 20, 12, 5, 3, RED)
	return img
