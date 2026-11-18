class_name FloraArt
extends RefCounted
## Sprites de la petite végétation, peints au chargement (pixel art, palette de l'herbe du sol) :
## un sprite par (type, variante, stade). Ancre en bas au milieu (pied de la plante).

const OUT := Color8(16, 34, 24)
const G := [Color8(29, 59, 37), Color8(36, 71, 43), Color8(45, 85, 50), Color8(56, 101, 58), Color8(71, 122, 64), Color8(106, 154, 80), Color8(141, 180, 100)]
## Teintes de feuillage par variante : décalage dans G.
const TINT := [0, 1, -1, 0]
const BARK := [Color8(52, 38, 28), Color8(78, 58, 40), Color8(104, 80, 54), Color8(138, 110, 76)]
const DRY := [Color8(86, 84, 48), Color8(118, 112, 62), Color8(150, 138, 80)]
const ASH := [Color8(30, 28, 27), Color8(52, 48, 44), Color8(82, 76, 68)]
const PETALS := [[Color8(214, 72, 70), Color8(240, 130, 110)], [Color8(232, 196, 72), Color8(250, 232, 140)],
	[Color8(230, 228, 214), Color8(255, 255, 246)], [Color8(150, 96, 196), Color8(196, 150, 230)]]
const THORN_RED := Color8(150, 46, 40)
const REED := [Color8(84, 112, 56), Color8(118, 142, 70), Color8(156, 170, 92)]
const CATTAIL := [Color8(70, 44, 28), Color8(104, 68, 40)]

static var _cache := {}


## Texture d'une plante ; `burnt` remplace le stade 0 par des cendres.
static func texture(k: String, v: int, stage: int, burnt := false) -> Texture2D:
	var key := "%s_%d_%d_%d" % [k, v, stage, 1 if burnt else 0]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(paint(k, v, stage, burnt))
	return _cache[key]


static func paint(k: String, v: int, stage: int, burnt: bool) -> Image:
	var r := Rng.new(hash([k, v]))
	if stage == 0 and k != "stump" and k != "log" and k != "moss":
		return _flattened(r, k, burnt)
	if stage == 1 and k != "stump" and k != "log" and k != "moss":
		return _sprout(r, v)
	var s := 0.65 if stage == 2 else 1.0
	match k:
		"bush": return _bush(r, v, s)
		"thorn": return _thorn(r, s)
		"grass": return _grass(r, v, s)
		"reed": return _reeds(r, v, s)
		"flowers": return _flowers(r, v, s)
		"moss": return _moss(r, v)
		"stump": return _stump(r, v)
		"log": return _log(r, v)
	return Image.create(1, 1, false, Image.FORMAT_RGBA8)


static func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _g(i: int, v: int) -> Color:
	return G[clampi(i + TINT[v % TINT.size()], 0, G.size() - 1)]


## Contour sombre autour de tout pixel opaque.
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
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and img.get_pixelv(q).a > 0.0 and img.get_pixelv(q) != OUT:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		img.set_pixelv(p, OUT)


## Buisson : grappe de boules de feuilles, éclairées en haut à gauche, baies ou fleurs parfois.
static func _bush(r: Rng, v: int, s: float) -> Image:
	var w := roundi((22 + v * 4) * s) + 4
	var h := roundi((15 + v * 3) * s) + 3
	var img := _img(w, h)
	var balls: Array[Vector3] = []
	for n in 4 + v:
		var rad := (3.4 + r.next() * 3.0) * s
		balls.append(Vector3(2 + rad + r.next() * (w - 4 - 2 * rad), h - 1 - rad - r.next() * (h - 2 - 2 * rad) * 0.8, rad))
	for y in h:
		for x in w:
			var best := -1.0
			var sh := 0.0
			for b in balls:
				var dx := (x + 0.5 - b.x) / b.z
				var dy := (y + 0.5 - b.y) / b.z
				var d := dx * dx + dy * dy
				if d < 1.0 and b.y > best:
					best = b.y
					sh = -dx * 0.5 - dy * 0.8 + (Rng.hash3(x, y, v) - 0.5) * 0.5
			if best >= 0.0:
				var i := 3 + clampi(roundi(sh * 2.2), -2, 3)
				_put(img, x, y, _g(i, v))
	if v == 1 or v == 3:
		var c: Color = PETALS[0][0] if v == 1 else PETALS[2][1]
		for n in 3 + roundi(3 * s):
			var x := 2 + floori(r.next() * (w - 4))
			var y := 1 + floori(r.next() * (h - 3))
			if img.get_pixel(x, y).a > 0.0:
				_put(img, x, y, c)
	_outline(img)
	return img


static func _thorn(r: Rng, s: float) -> Image:
	var w := roundi(20 * s) + 4
	var h := roundi(13 * s) + 3
	var img := _img(w, h)
	for n in 7:
		var p := Vector2(w * 0.5 + (r.next() - 0.5) * 6.0, h - 1)
		var a := -PI * 0.5 + (r.next() - 0.5) * 2.4
		for t in roundi((7 + r.next() * 8) * s):
			_put(img, roundi(p.x), roundi(p.y), BARK[1] if t % 3 else BARK[0])
			if r.next() < 0.18:
				_put(img, roundi(p.x) + 1, roundi(p.y), THORN_RED)
			elif r.next() < 0.22:
				_put(img, roundi(p.x), roundi(p.y) - 1, G[2])
			p += Vector2(cos(a), sin(a))
			a += (r.next() - 0.5) * 0.9
	_outline(img)
	return img


## Hautes herbes : brins penchés, plus clairs vers la pointe.
static func _grass(r: Rng, v: int, s: float) -> Image:
	var w := 13
	var h := roundi(14 * s) + 2
	var img := _img(w, h)
	for n in 7 + v:
		var x := 2.0 + r.next() * (w - 4)
		var hb := (h - 3) * (0.55 + r.next() * 0.45)
		var lean := (r.next() - 0.5) * 0.5
		for t in roundi(hb):
			var f := float(t) / hb
			_put(img, roundi(x + lean * t), h - 1 - t, _g(1 + roundi(f * 4.0), v))
	return img


static func _reeds(r: Rng, v: int, s: float) -> Image:
	var w := 11
	var h := roundi(22 * s) + 2
	var img := _img(w, h)
	for n in 4 + v % 3:
		var x := 1.5 + r.next() * (w - 3)
		var hb := (h - 2) * (0.6 + r.next() * 0.4)
		var lean := (r.next() - 0.5) * 0.18
		for t in roundi(hb):
			_put(img, roundi(x + lean * t), h - 1 - t, REED[mini(2, t * 3 / maxi(1, roundi(hb)))])
		if r.next() < 0.6 and s > 0.9:
			var tx := roundi(x + lean * hb)
			for t in 4:
				_put(img, tx, h - 1 - roundi(hb) + 2 + t, CATTAIL[1 if t == 0 else 0])
	# Feuilles en ruban à la base.
	for n in 3:
		var x := 2.0 + r.next() * (w - 4)
		var dir := 1.0 if r.next() < 0.5 else -1.0
		for t in 5:
			_put(img, roundi(x + dir * t * 0.6), h - 1 - t, REED[1])
	return img


## Massif de fleurs posé au sol (couche plate).
static func _flowers(r: Rng, v: int, s: float) -> Image:
	var w := 16
	var h := 10
	var img := _img(w, h)
	for n in 14:
		_put(img, floori(r.next() * w), floori(r.next() * h), G[2 + floori(r.next() * 3.0)])
	var pet: Array = PETALS[v % PETALS.size()]
	for n in roundi(6 * s):
		var x := 1 + floori(r.next() * (w - 3))
		var y := 1 + floori(r.next() * (h - 3))
		_put(img, x, y, pet[0])
		_put(img, x + 1, y, pet[0])
		_put(img, x, y + 1, pet[0])
		_put(img, x + 1, y + 1, pet[1])
	return img


static func _moss(r: Rng, v: int) -> Image:
	var w := 18
	var h := 10
	var img := _img(w, h)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w * 0.5) / (w * 0.5)
			var dy := (y + 0.5 - h * 0.5) / (h * 0.5)
			var d := dx * dx + dy * dy + (Rng.vnoise(x * 0.4, y * 0.4, v + 7) - 0.5) * 0.8
			var n := Rng.hash3(x, y, v + 3)
			if d < 0.7 or (d < 1.0 and n < 0.5):
				_put(img, x, y, G[5] if n < 0.15 else G[4] if n < 0.6 else G[3])
	return img


static func _stump(r: Rng, v: int) -> Image:
	var w := 12
	var h := 10
	var img := _img(w, h)
	for y in range(3, h):
		for x in range(2, w - 2):
			_put(img, x, y, BARK[1] if (x + y * 3) % 5 else BARK[0])
	for y in 5:
		for x in range(2, w - 2):
			var dx := (x + 0.5 - w * 0.5) / ((w - 4) * 0.5)
			var dy := (y + 0.5 - 2.5) / 2.5
			if dx * dx + dy * dy < 1.0:
				_put(img, x, y, BARK[3] if dx * dx + dy * dy > 0.35 else BARK[2])
	if v % 2 == 0:
		for x in range(2, w - 2, 2):
			_put(img, x, h - 1, G[4])
	_outline(img)
	return img


static func _log(r: Rng, v: int) -> Image:
	var w := 28
	var h := 9
	var img := _img(w, h)
	for y in range(1, h - 1):
		for x in range(1, w - 4):
			_put(img, x, y, BARK[2] if y == 2 else BARK[1] if (x * 7 + y) % 9 else BARK[0])
	for y in range(1, h - 1):
		for x in range(w - 5, w - 1):
			_put(img, x, y, BARK[3] if (x + y) % 3 else BARK[2])
	for x in range(2, w - 6):
		if Rng.hash3(x, v, 5) < 0.45:
			_put(img, x, 1, G[4])
			_put(img, x, 0, G[3])
	_outline(img)
	return img


## Pousse : deux ou trois petites feuilles.
static func _sprout(r: Rng, v: int) -> Image:
	var img := _img(7, 5)
	for p: Vector2i in [Vector2i(3, 4), Vector2i(3, 3), Vector2i(2, 2), Vector2i(4, 2), Vector2i(1, 1), Vector2i(5, 1)]:
		_put(img, p.x, p.y, _g(4 if p.y < 3 else 2, v))
	return img


## Plante couchée (piétinée) ou brûlée : tache basse.
static func _flattened(r: Rng, k: String, burnt: bool) -> Image:
	var w := 14
	var h := 4
	var img := _img(w, h)
	var pal: Array = ASH if burnt else DRY
	for n in 16:
		_put(img, floori(r.next() * w), 1 + floori(r.next() * (h - 1)), pal[floori(r.next() * pal.size())])
	return img
