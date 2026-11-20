class_name Terrain
extends Node2D
## Sol du monde, en blocs de 1024² pixels sur une grille qui couvre toute la carte.
## - Les 16 blocs du baker (buildPixelWorld, 73b410f) gardent la zone d'origine ; leurs marges noires
##   (hors CaveShape.START_*) sont repeintes au chargement avec le sol généré.
## - Ailleurs, le sol « vierge » est généré : dessus de roche au-dessus du flanc de la montagne, herbe de
##   jungle en dessous, liseré à la lisière. Un bloc de roche pure (ou d'herbe pure) n'est qu'un sprite à
##   texture répétée tant que personne n'y peint ; il devient une `Image` modifiable au premier coup de
##   pinceau (creusement, galerie révélée). Les blocs de lisière sont peints dès le chargement.
## Les textures sont lues en coordonnées absolues du sol (origine du baker conservée, indices de bloc
## négatifs permis) : une case repeinte se raccorde toujours à ses voisines.
## Les positions sont en pixels natifs, sous le nœud World mis à l'échelle ×PX ; le matériau
## d'alignement (pixel_snap) est hérité du parent.

const BAKED := "res://assets/baked/"
const GRASS_PERIOD := 512
## Marge peinte autour des bornes de la carte (unités), comme la marge du sol du baker.
const MARGIN := 6.0
## Rangées de cases du bord du sol baké remplacées par le sol généré (unités).
const BAKED_RIM := 8.0


## Lisière en escalier, comme le sol du baker : une case de 4 unités est de l'herbe quand le centre de la
## case est au sud du flanc de la montagne.
static func grass_cell(x: float, z: float) -> bool:
	var cx := floorf(x / 4.0) * 4.0 + 2.0
	var cz := floorf(z / 4.0) * 4.0 + 2.0
	return cz >= CaveShape.mountain_edge(cx)

## Pixel du sol où se trouve l'origine du monde (0, 0, 0).
var origin := Vector2i.ZERO
var chunk := 1024
## Bornes de la grille de blocs (indices inclus).
var cmin := Vector2i.ZERO
var cmax := Vector2i.ZERO
## Vector2i(c, r) → bloc peint : {"image": Image, "texture": ImageTexture, "sprite": Sprite2D}.
var _blocks := {}
## Vector2i(c, r) → "rock" | "grass" : bloc vierge affiché par un sprite à texture répétée.
var _plain := {}
var _plain_sprites := {}
var _rock: Image
var _grass: Image
var _rock_tex: Texture2D
var _grass_tex: Texture2D
var _rock_c: Array[Color] = []
var materialized := 0


func build() -> void:
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BAKED + "manifest.json"))["world"]["ground"]
	origin = Vector2i(int(g["gx0"]), int(g["gy0"]))
	chunk = int(g["chunk"])
	_rock_tex = load(ArtStyle.TILES + "rock.png")
	_grass_tex = load(ArtStyle.TILES + "grass.png")
	_rock = _rgba(_rock_tex)
	_grass = _rgba(_grass_tex)
	_rock_c.clear()
	var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArtStyle.PALETTE))
	for hex: String in palette["rock"]:
		_rock_c.append(Color(hex))
	for child in get_children():
		child.free()
	_blocks.clear()
	_plain.clear()
	_plain_sprites.clear()
	materialized = 0
	var p0 := _px(CaveShape.WORLD_X0 - MARGIN, CaveShape.WORLD_Z0 - MARGIN)
	var p1 := _px(CaveShape.WORLD_X1 + MARGIN, CaveShape.WORLD_Z1 + MARGIN)
	cmin = Vector2i(floori(p0.x / float(chunk)), floori(p0.y / float(chunk)))
	cmax = Vector2i(floori((p1.x - 1) / float(chunk)), floori((p1.y - 1) / float(chunk)))
	# Blocs du baker.
	for r in int(g["rows"]):
		for c in int(g["cols"]):
			var image := _rgba(load(ArtStyle.GROUND % [r, c]))
			_add_block(Vector2i(c, r), image)
	# Marges du baker hors de la zone d'origine : sol généré (cases entières hors de la zone).
	# La dernière rangée de cases du baker porte un liseré de bord de carte : repeinte elle aussi.
	var s0 := _px(CaveShape.START_X0 + BAKED_RIM, CaveShape.START_Z0 + BAKED_RIM)
	var s1 := _px(CaveShape.START_X1 - BAKED_RIM, CaveShape.START_Z1 + MARGIN)
	for key: Vector2i in _blocks.keys():
		var rect := Rect2i(key * chunk, Vector2i(chunk, chunk))
		_paint_pristine(rect, Rect2i(s0, s1 - s0))
	# Le reste de la grille : roche pure, herbe pure ou bloc de lisière peint tout de suite.
	for r in range(cmin.y, cmax.y + 1):
		for c in range(cmin.x, cmax.x + 1):
			var key := Vector2i(c, r)
			if _blocks.has(key):
				continue
			var kind := _block_kind(key)
			if kind.is_empty():
				_materialize(key)
			else:
				_add_plain(key, kind)
	flush()


static func _rgba(tex: Texture2D) -> Image:
	var image := tex.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


## Pixel du sol du point (x, z) du monde.
func _px(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x * 8.0) + origin.x, floori(z * 8.0) + origin.y)


## Le flanc de la montagne oscille entre z −85 et −71 : en dehors, un bloc est uniforme.
func _block_kind(key: Vector2i) -> String:
	var z0 := float(key.y * chunk - origin.y) / 8.0
	var z1 := float((key.y + 1) * chunk - origin.y) / 8.0
	if z1 < -86.0:
		return "rock"
	if z0 > -70.0:
		return "grass"
	return ""


## Teinte du sol et de la roche d'un bloc selon son biome : vert-de-gris au nord du Temple (biome 2).
const BIOME_TINT: Array[Color] = [Color.WHITE, Color(0.72, 0.96, 0.86)]


func _biome_tint(key: Vector2i) -> Color:
	var z := (float(key.y * chunk - origin.y) + chunk * 0.5) / 8.0
	return BIOME_TINT[mini(Biomes.index_at(z), BIOME_TINT.size() - 1)]


func _add_block(key: Vector2i, image: Image) -> void:
	var texture := ImageTexture.create_from_image(image)
	var s := Sprite2D.new()
	s.name = "Ground_r%d_c%d" % [key.y, key.x]
	s.texture = texture
	s.centered = false
	s.position = Vector2(key * chunk - origin)
	s.use_parent_material = true
	s.modulate = _biome_tint(key)
	add_child(s)
	_blocks[key] = {"image": image, "texture": texture, "sprite": s}


func _add_plain(key: Vector2i, kind: String) -> void:
	var s := Sprite2D.new()
	s.name = "Plain_r%d_c%d" % [key.y, key.x]
	var period := ArtStyle.PERIOD if kind == "rock" else GRASS_PERIOD
	s.texture = _rock_tex if kind == "rock" else _grass_tex
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(posmod(key.x * chunk, period), posmod(key.y * chunk, period), chunk, chunk)
	s.centered = false
	s.position = Vector2(key * chunk - origin)
	s.use_parent_material = true
	s.modulate = _biome_tint(key)
	add_child(s)
	_plain[key] = kind
	_plain_sprites[key] = s


## Bloc vierge → image modifiable (sol généré), à la place de son sprite répété.
func _materialize(key: Vector2i) -> void:
	var image := Image.create(chunk, chunk, false, Image.FORMAT_RGBA8)
	var at := key * chunk
	var kind: String = _plain.get(key, "")
	if kind == "rock" or kind == "grass":
		_tile(image, _rock if kind == "rock" else _grass, ArtStyle.PERIOD if kind == "rock" else GRASS_PERIOD, at, Rect2i(Vector2i.ZERO, image.get_size()))
	if _plain_sprites.has(key):
		(_plain_sprites[key] as Sprite2D).free()
		_plain_sprites.erase(key)
		_plain.erase(key)
	_add_block(key, image)
	if kind.is_empty():
		_paint_pristine(Rect2i(at, Vector2i(chunk, chunk)), Rect2i())
	materialized += 1
	_dirty[key] = true


## Remplit `local` (pixels de l'image) avec la texture périodique `tex`, en coordonnées absolues du sol.
static func _tile(image: Image, tex: Image, period: int, at: Vector2i, local: Rect2i) -> void:
	var y := local.position.y
	while y < local.end.y:
		var ty := posmod(at.y + y, period)
		var h := mini(period - ty, local.end.y - y)
		var x := local.position.x
		while x < local.end.x:
			var tx := posmod(at.x + x, period)
			var w := mini(period - tx, local.end.x - x)
			image.blit_rect(tex, Rect2i(tx, ty, w, h), Vector2i(x, y))
			x += w
		y += h


## Sol vierge (roche / herbe / lisière) sur `rect` (pixels du sol), par cases de 4 unités, en laissant
## intactes les cases entièrement dans `keep`.
func _paint_pristine(rect: Rect2i, keep: Rect2i) -> void:
	# Les cases à cheval sur un bloc voisin encore vierge ne le matérialisent pas : il est déjà juste.
	_pristine = true
	var w0 := Vector2(rect.position - origin) / 8.0
	var w1 := Vector2(rect.end - origin) / 8.0
	var z := floorf(w0.y / 4.0) * 4.0
	while z < w1.y:
		var x := floorf(w0.x / 4.0) * 4.0
		while x < w1.x:
			var cell := Rect2i(_px(x, z), Vector2i(32, 32))
			if keep.size == Vector2i.ZERO or not keep.encloses(cell):
				_paint_pristine_cell(x, z)
			x += 4.0
		z += 4.0
	_pristine = false


var _pristine := false


func _paint_pristine_cell(x: float, z: float) -> void:
	var any := false
	var all := true
	for o: Vector2 in [Vector2(-2, 2), Vector2(6, 2), Vector2(2, -2), Vector2(2, 6), Vector2(2, 2)]:
		var h := grass_cell(x + o.x, z + o.y)
		any = any or h
		all = all and h
	all = grass_cell(x + 2.0, z + 2.0) and all
	var p := _px(x, z)
	var tile := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	if not any or all:
		_tile(tile, _grass if all else _rock, GRASS_PERIOD if all else ArtStyle.PERIOD, p, Rect2i(0, 0, 32, 32))
		blit(tile, p.x, p.y)
		return
	# Lisière : masque d'herbe à 1/8 d'unité (marge de 3 px), roche et liseré selon les règles du peintre.
	const M := 38
	var mask := PackedByteArray()
	mask.resize(M * M)
	for py in range(-3, 35):
		for px in range(-3, 35):
			mask[(py + 3) * M + px + 3] = 1 if grass_cell(x + px / 8.0, z + py / 8.0) else 0
	_tile(tile, _rock, ArtStyle.PERIOD, p, Rect2i(0, 0, 32, 32))
	for py in 32:
		for px in 32:
			var m := (py + 3) * M + px + 3
			if mask[m] == 1:
				tile.set_pixel(px, py, _grass.get_pixel(posmod(p.x + px, GRASS_PERIOD), posmod(p.y + py, GRASS_PERIOD)))
			elif mask[m + 2 * M] == 1 and mask[m - 3 * M] == 0:
				var c := tile.get_pixel(px, py)
				tile.set_pixel(px, py, Color(c.r * 0.55, c.g * 0.55, c.b * 0.55))
			elif mask[m - 2 * M] == 1:
				tile.set_pixel(px, py, _rock_c[7 if mask[m - M] == 1 else 5])
			elif mask[m - 2] == 1 or mask[m + 2] == 1:
				tile.set_pixel(px, py, _rock_c[0] if mask[m - 1] == 1 or mask[m + 1] == 1 else _rock_c[6])
	blit(tile, p.x, p.y)


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
	for key: Vector2i in _dirty:
		if _blocks.has(key):
			var b: Dictionary = _blocks[key]
			(b["texture"] as ImageTexture).update(b["image"])
	_dirty.clear()


var _dirty := {}


## Appelle fn(image du bloc, rectangle local dans le bloc, origine du bloc en pixels du sol) pour chaque
## bloc touché par `rect` (pixels du sol). Un bloc vierge touché est d'abord rendu modifiable.
func _for_chunks(rect: Rect2i, fn: Callable) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var c0 := maxi(cmin.x, floori(rect.position.x / float(chunk)))
	var c1 := mini(cmax.x, floori((rect.end.x - 1) / float(chunk)))
	var r0 := maxi(cmin.y, floori(rect.position.y / float(chunk)))
	var r1 := mini(cmax.y, floori((rect.end.y - 1) / float(chunk)))
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var key := Vector2i(c, r)
			var origin_px := key * chunk
			var inter := rect.intersection(Rect2i(origin_px, Vector2i(chunk, chunk)))
			if inter.size.x <= 0 or inter.size.y <= 0:
				continue
			if not _blocks.has(key):
				if _pristine:
					continue
				_materialize(key)
			fn.call(_blocks[key]["image"], Rect2i(inter.position - origin_px, inter.size), origin_px)
			_dirty[key] = true


## Copie d'un rectangle du sol (coordonnées du sol) ; pixels hors du sol transparents.
func copy_region(at: Vector2i, size: Vector2i) -> Image:
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			out.set_pixel(x, y, get_ground_pixel(at.x + x, at.y + y))
	return out


## Couleur du sol au pixel (px, py) (coordonnées du sol, pas du monde).
func get_ground_pixel(px: int, py: int) -> Color:
	var key := Vector2i(floori(px / float(chunk)), floori(py / float(chunk)))
	if _blocks.has(key):
		return (_blocks[key]["image"] as Image).get_pixel(px - key.x * chunk, py - key.y * chunk)
	match _plain.get(key, ""):
		"rock":
			return _rock.get_pixel(posmod(px, ArtStyle.PERIOD), posmod(py, ArtStyle.PERIOD))
		"grass":
			return _grass.get_pixel(posmod(px, GRASS_PERIOD), posmod(py, GRASS_PERIOD))
	return Color(0, 0, 0, 0)


# ---------------------------------------------------------------- Chemins de la jungle (Road)

func _set_ground(px: int, py: int, c: Color) -> void:
	var key := Vector2i(floori(px / float(chunk)), floori(py / float(chunk)))
	if not _blocks.has(key):
		if not _plain.has(key):
			return
		_materialize(key)
	(_blocks[key]["image"] as Image).set_pixel(px - key.x * chunk, py - key.y * chunk, c)
	_dirty[key] = true


func _grass_px(p: Vector2i) -> Color:
	return _grass.get_pixel(posmod(p.x, GRASS_PERIOD), posmod(p.y, GRASS_PERIOD))


## Remplace la bande droite du sol baké par les chemins de `road` : herbe sur l'ancienne bande, terre
## (texture reprise de l'ancienne chaussée) le long des virages et des chemins secondaires, ornières.
func paint_road(road: Road) -> void:
	var z0 := Road.GATE_Z
	var z1 := CaveShape.WORLD_Z1 + MARGIN
	# Texture source : l'ancienne chaussée, x −4,5…4,5.
	var s0 := _px(-4.5, z0)
	var sw := 72
	# Bord sud exclu (marge sombre de la carte) : la texture boucle sur de la chaussée seulement.
	var sh := int((CaveShape.WORLD_Z1 - 4.0 - z0) * 8.0)
	var src := copy_region(s0, Vector2i(sw, sh))
	var pave := func(p: Vector2i, u: float, along: float, ruts: bool) -> void:
		var c := src.get_pixel(clampi(roundi((u * 0.5 + 0.5) * (sw - 1)), 0, sw - 1), posmod(floori(along * 8.0), sh))
		if ruts and (absf(u - 0.4) < 0.08 or absf(u + 0.4) < 0.08):
			c = Color(c.r * 0.78, c.g * 0.76, c.b * 0.74, 1.0)
		_set_ground(p.x, p.y, c)
	# Route principale, rangée par rangée.
	var py0 := _px(0.0, z0).y
	var py1 := _px(0.0, z1).y
	for py in range(py0, py1):
		var z := (py - origin.y + 0.5) / 8.0
		var mx := road.main_x(z)
		var xa := minf(mx - Road.MAIN_HALF - 1.0, -5.5)
		var xb := maxf(mx + Road.MAIN_HALF + 1.0, 5.5)
		for px in range(_px(xa, 0.0).x, _px(xb, 0.0).x):
			var x := (px - origin.x + 0.5) / 8.0
			var e := (Rng.hash3(px, py, 0x40ad) - 0.5) * 0.9 + 0.35 * sin(z * 0.9 + x * 0.3)
			# Bord irrégulier : l'herbe mord sur la chaussée par touffes lentes, différentes de chaque côté,
			# en plus du grain au pixel (sinon le bord se lit comme un trait au cordeau).
			var side := 1.0 if x > mx else -1.0
			var bite := 0.55 * sin(z * 1.9 + side * 2.1) * sin(z * 0.53 + side) + 0.3 * sin(z * 4.3 + side * 5.0)
			var d := absf(x - mx) - Road.MAIN_HALF + bite
			var p := Vector2i(px, py)
			if d + e < 0.0:
				pave.call(p, (x - mx) / Road.MAIN_HALF, z, true)
			elif absf(x) < 5.2:
				_set_ground(px, py, _grass_px(p))
	# Chemins secondaires.
	for j in road.junctions:
		var hw := Road.BRANCH_HALF
		var jx: float = j["x"]
		var bx: float = j["bx"]
		for px in range(_px(minf(jx, bx), 0.0).x, _px(maxf(jx, bx), 0.0).x):
			var x := (px - origin.x + 0.5) / 8.0
			var bz := road.branch_z(j, x)
			for py in range(_px(0.0, bz - hw - 1.0).y, _px(0.0, bz + hw + 1.0).y):
				var z := (py - origin.y + 0.5) / 8.0
				if absf(x - road.main_x(z)) < Road.MAIN_HALF - 0.3:
					continue
				var side := 1.0 if z > bz else -1.0
				var e := (Rng.hash3(px, py, 0x40ae) - 0.5) * 0.9 + 0.5 * sin(x * 1.9 + side * 2.1) * sin(x * 0.53 + side) + 0.28 * sin(x * 4.3 + side * 5.0)
				if absf(z - bz) - hw + e < 0.0:
					pave.call(Vector2i(px, py), (z - bz) / hw, x, true)
		var b: Dictionary = j["b"]
		var zt := road.branch_z(j, bx) - hw
		var zb := float(b["z1"]) + 9.0
		for py in range(_px(0.0, zt).y, _px(0.0, zb).y):
			var z := (py - origin.y + 0.5) / 8.0
			var fade := clampf((zb - z) / 3.0, 0.0, 1.0)
			for px in range(_px(bx - hw - 1.0, 0.0).x, _px(bx + hw + 1.0, 0.0).x):
				var x := (px - origin.x + 0.5) / 8.0
				var e := (Rng.hash3(px, py, 0x40af) - 0.5) * 0.8 + (1.0 - fade) * 2.5
				if absf(x - bx) - hw + e < 0.0:
					pave.call(Vector2i(px, py), (x - bx) / hw, z, false)
	flush()
