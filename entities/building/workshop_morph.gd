class_name WorkshopMorph
extends RefCounted
## Pièces de bois de l'Atelier (Table d'énonciation) : elles prennent la silhouette de l'objet en cours de
## fabrication, au rythme de Building.craft, puis l'éclat d'Aether les change en l'icône de l'objet, qui file
## vers le coffre de sortie. Planche : planches/atelier-morph-propositions.html (tools/atelier-morph/morph.js,
## dont ce fichier reprend formes et matières). La boucle da-workshop_anim.png est exportée sans pièces
## (tools/atelier-morph/export.py).
const ItemIcon := preload("res://ui/inventory/item_icon.gd")
const Recipes := preload("res://data/recipes.gd")

## Tampon de dessin, en pixels du sprite ; C = point d'assemblage dans le tampon.
const W := 96
const H := 72
const C := Vector2i(48, 38)
## Point d'assemblage dans le repère 320 × 240 du sprite : at(0, 1.45, 0) pour l'ancre (160, 168) à 24 px par unité.
const SPOT := Vector2(160, 133)
const FPS := 12.0
## Après l'achèvement : anneau, icône qui flotte, puis trajet vers le coffre rouge (secondes de simulation).
const RING := 0.5
const HOVER := 0.7
const TRAVEL := 0.6
const EMISSIVE := 0x1000000

## Matières : ton clair, moyen, sombre (WOOD, BARK, IRON, SLATE, CANVAS du moteur des planches).
const MAT := {
	"W": [0x8e663c, 0x74502f, 0x5a3a24], "B": [0x6b4629, 0x52341f, 0x3a2416], "I": [0x7c8692, 0x5e6772, 0x323840],
	"R": [0x5e6c7e, 0x4c5868, 0x2a3240], "F": [0xc4b896, 0xa89c7c, 0x6a604a], "G": [0x8a7e62, 0x6a604a, 0x4a4234],
	"L": [0xd8584a, 0xb03c34, 0x7a2424],
}
const FLAME := [0xffe9a0, 0xffb030, 0xe86a18]
const AETHER := [0x9aa0ff, 0xe0e4ff]
## Une pièce cible = [x0, y0, x1, y1, matière, épaisseur], en pixels autour du point d'assemblage (y vers le bas).
const SHAPES := {
	"torch": [[-7, 12, -2, 3, "W", 3], [-2, 3, 2, -4, "W", 3], [2, -4, 5, -9, "G", 5]],
	"pickaxe": [[-8, 12, -1, 1, "W", 3], [-1, 1, 5, -8, "W", 3], [-9, -8, 0, -11, "I", 3], [0, -11, 8, -9, "I", 3],
		[8, -9, 12, -3, "I", 2]],
	"arrows": [[-13, 7, 3, -11, "W", 2], [3, -11, 5, -14, "I", 3], [-13, 7, -15, 10, "L", 3],
		[-9, 10, 7, -8, "W", 2], [7, -8, 9, -11, "I", 3], [-9, 10, -11, 13, "L", 3],
		[-5, 13, 11, -5, "W", 2], [11, -5, 13, -8, "I", 3], [-5, 13, -7, 16, "L", 3]],
	"chest": [[-11, -8, 11, -8, "W", 4], [-11, -3, 11, -3, "W", 4], [-11, 2, 11, 2, "W", 4], [-11, 7, 11, 7, "W", 4],
		[-8, -8, -8, 10, "I", 2], [7, -8, 7, 10, "I", 2], [-1, -3, -1, 0, "I", 3]],
	"wood_fiber": [[-11, -7, 11, -7, "F", 3], [-11, -2, 11, -2, "F", 3], [-11, 3, 11, 3, "F", 3], [-11, 8, 11, 8, "F", 3],
		[-6, -9, -6, 11, "G", 2], [4, -9, 4, 11, "G", 2]],
	"firing_post": [[-12, -10, -12, 10, "W", 4], [-7, -7, -7, 10, "W", 4], [-2, -10, -2, 10, "W", 4],
		[3, -7, 3, 10, "W", 4], [8, -10, 8, 10, "W", 4], [-12, -3, 11, -3, "B", 2], [-12, 5, 11, 5, "B", 2]],
	"barricade": [[-7, 9, -1, 9, "R", 4], [1, 8, 7, 8, "R", 5], [-12, -9, 12, 7, "W", 4], [-12, 7, 12, -9, "W", 4],
		[-13, 1, 13, 1, "W", 3]],
	"fishing_rod": [[-10, 12, -3, 3, "W", 2], [-3, 3, 5, -7, "W", 2], [5, -7, 9, -12, "W", 1], [-10, 9, -8, 11, "I", 4],
		[9, -12, 10, 5, "F", 1], [10, 5, 8, 8, "I", 2]],
	"bow": [[-5, -12, 2, -7, "W", 3], [2, -7, 4, 0, "W", 3], [4, 0, 2, 7, "W", 3], [2, 7, -5, 12, "W", 3],
		[-5, -12, -5, 12, "F", 1]],
	"caltrops": [[-6, 1, -6, 6, "I", 2], [-6, 6, -10, 10, "I", 2], [-5, 6, -1, 10, "I", 2],
		[6, 1, 6, 6, "I", 2], [6, 6, 2, 10, "I", 2], [7, 6, 11, 10, "I", 2],
		[0, -11, 0, -6, "I", 2], [0, -6, -4, -2, "I", 2], [1, -6, 5, -2, "I", 2]],
}

var _px := PackedInt32Array()
var _bytes := PackedByteArray()
var _tex: ImageTexture
var _key := -1
## Suivi de la fabrication, pour repérer l'achèvement (la progression retombe à zéro sur la même recette).
var _craft := 0.0
var _recipe := ""
var _shape := "barricade"
var _done_at := -INF
var _done_item := ""


static func _ease(p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	return p * p * (3.0 - 2.0 * p)


static func _hash(k: int, s: int) -> float:
	return fposmod(sin(k * 12.9898 + s * 78.233) * 43758.5453, 1.0)


func _plot(x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		_px[y * W + x] = c


func _bar(a: Vector2, b: Vector2, m: Array, w: int) -> void:
	var flat := absf(b.x - a.x) >= absf(b.y - a.y)
	var n := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for k in w:
		var c: int = m[0 if k == 0 else (2 if k == w - 1 else 1)]
		var o := Vector2(0, k) if flat else Vector2(k, 0)
		for i in n + 1:
			var p := a.lerp(b, i / float(n)) + o
			_plot(C.x + roundi(p.x), C.y + roundi(p.y), c)


## Progression q (0 à 1) de la fabrication en cours ; ring ≥ 0 : âge de l'éclat d'achèvement, en secondes.
func _raster(q: float, t: float, ring: float) -> void:
	_px.fill(-1)
	var S: Array = SHAPES[_shape]
	var n := S.size()
	var rise := _ease(q / 0.08)
	var last := 0.0
	for k in n:
		var s: Array = S[k]
		var ta := Vector2(s[0], s[1])
		var tb := Vector2(s[2], s[3])
		var p := _ease((q - 0.08 - 0.3 * k / n) / 0.5)
		last = p
		var ang_t := (tb - ta).angle()
		# Posée sur la table, puis en vol désordonné, puis à sa place.
		var lying := Vector2((_hash(k, 2) - 0.5) * 30.0, 20.0 + (k % 3) * 2.0)
		var floating := Vector2((_hash(k, 3) - 0.5) * 46.0, (_hash(k, 4) - 0.5) * 16.0 - 4.0 + sin(t * PI + k) * 2.0)
		var spin := ang_t + (_hash(k, 1) - 0.5) * 5.0 + (1.0 - p) * t * TAU / 6.0
		var pos := lying.lerp(floating, rise).lerp((ta + tb) * 0.5, p)
		var ang := lerpf(lerpf(0.0, spin, rise), ang_t, p)
		var half := lerpf(8.0, ta.distance_to(tb) * 0.5, p)
		var d := Vector2.from_angle(ang) * half
		_bar(pos - d, pos + d, MAT[s[4] if p > 0.6 else "W"], maxi(1, roundi(lerpf(2.0, s[5], p))))
	if _shape == "torch" and last > 0.9:
		for j in 5:
			var wd := 2 if j < 3 else 1
			for i in range(-wd, wd + 1):
				if _hash(i + 7 * j, floori(t * 8.0)) > 0.25:
					_plot(C.x + 5 + i, C.y - 10 - j, FLAME[2 if j > 3 or absi(i) > 1 else (1 if j > 1 else 0)] | EMISSIVE)
	if ring >= 0.0 and ring < RING:
		var r := 8.0 + ring / RING * 20.0
		for k in 40:
			var a := k * TAU / 40.0
			_plot(C.x + roundi(cos(a) * r), C.y + roundi(sin(a) * r * 0.7), AETHER[k % 2] | EMISSIVE)
	_outline()
	for i in W * H:
		var v := _px[i]
		var o := i * 4
		if v < 0:
			_bytes[o + 3] = 0
		else:
			_bytes[o] = (v >> 16) & 255
			_bytes[o + 1] = (v >> 8) & 255
			_bytes[o + 2] = v & 255
			_bytes[o + 3] = 255
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, _bytes)
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)


## Contour coloré des planches : ton assombri autour des pixels non lumineux qui ont au moins trois voisins.
func _outline() -> void:
	var src := _px.duplicate()
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var i := y * W + x
			var v := src[i]
			if v < 0 or v & EMISSIVE:
				continue
			var n := 0
			for k: int in [-W - 1, -W, -W + 1, -1, 1, W - 1, W, W + 1]:
				if src[i + k] >= 0 and not (src[i + k] & EMISSIVE):
					n += 1
			if n < 3:
				continue
			var dark := (int(((v >> 16) & 255) * 0.32) << 16) | (int(((v >> 8) & 255) * 0.32) << 8) | int((v & 255) * 0.32)
			for k: int in [-W, -1, 1, W]:
				if src[i + k] < 0:
					_px[i + k] = dark


## À appeler depuis BuildingView._draw, dans le repère 320 × 240 du sprite (transformation déjà posée).
## chest : coffre de sortie dans ce même repère.
func draw(ci: CanvasItem, b: Building, chest: Vector2) -> void:
	var t := GameState.sim_time
	var total := Recipes.craft_time(b.type)
	if b.recipe != "" and b.recipe == _recipe and b.craft < _craft and _craft >= total * 0.5:
		_done_at = t
		_done_item = b.recipe
	_craft = b.craft
	_recipe = b.recipe
	if SHAPES.has(b.recipe):
		_shape = b.recipe
	var since := t - _done_at
	if since < 0.0:
		_done_at = -INF
		since = INF
	var key := floori(t * FPS)
	if key != _key or _tex == null:
		_key = key
		if _px.is_empty():
			_px.resize(W * H)
			_bytes.resize(W * H * 4)
		_raster(clampf(b.craft / total, 0.0, 1.0) if b.recipe != "" else 0.0, key / FPS, since if since < RING else -1.0)
	ci.draw_texture(_tex, SPOT - Vector2(C))
	if since < HOVER + TRAVEL:
		var u := _ease((since - HOVER) / TRAVEL)
		var bob := roundf(sin(t * 3.0) * 1.2) * (1.0 - u)
		var at := SPOT.lerp(chest, u) + Vector2(0.0, bob - sin(u * PI) * 10.0)
		ItemIcon.draw_item(ci, _done_item, at.round(), 1.0)
