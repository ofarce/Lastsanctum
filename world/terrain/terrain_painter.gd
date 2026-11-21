class_name TerrainPainter
extends RefCounted
## Repeint le sol après un creusement ou la révélation d'une galerie, avec les règles du prototype
## (73b410f, adepts.js : digCell ; galleries.js : paintRegion) et les textures du style ardoise.
##
## Les textures (dalles, dessus de roche, terre creusée) sont périodiques et lues en coordonnées
## absolues du sol, comme le sol complet généré par tools/ardoise/ardoise.py : une case repeinte se
## raccorde à ses voisines. Pour les cases à moitié creuses : masque pixel par pixel et règles de bord.
## Le travail se fait sur des tableaux d'octets RGBA (bien plus rapide que get_pixel / set_pixel).

const TILE := 32
## Le masque couvre la tuile et une marge de 3 px (les règles de bord regardent jusqu'à ±3 px).
const M := 38

var terrain: Terrain
var state: TerrainState
var stats := {"full": 0, "mixed": 0, "skip": 0}
## Textures et teintes de bord par palier de roche (Biomes.rock_tier) : [Temple, vert-de-gris].
## Le sol du biome 2 porte sa teinte dans floor2 / dug2 (elle suit la frontière à la case près).
var _floor_tex: Array[PackedByteArray] = []
var _rock_tex: Array[PackedByteArray] = []
var _dug_tex: Array[PackedByteArray] = []
var _rock_c: Array = []


func _init(ground: Terrain, terrain_state: TerrainState) -> void:
	terrain = ground
	state = terrain_state
	var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArtStyle.PALETTE))
	for suffix: String in ["", "2"]:
		_floor_tex.append(_rgba(load(ArtStyle.TILES + "floor%s.png" % suffix)).get_data())
		_rock_tex.append(_rgba(load(ArtStyle.TILES + "rock%s.png" % suffix)).get_data())
		_dug_tex.append(_rgba(load(ArtStyle.TILES + "dug%s.png" % suffix)).get_data())
		var edge: Array[PackedByteArray] = []
		for hex: String in palette["rock" + suffix]:
			edge.append(_bytes(hex))
		_rock_c.append(edge)


static func _rgba(tex: Texture2D) -> Image:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _bytes(hex: String) -> PackedByteArray:
	var c := Color(hex)
	return PackedByteArray([c.r8, c.g8, c.b8, 255])


static func _image(data: PackedByteArray) -> Image:
	return Image.create_from_data(TILE, TILE, false, Image.FORMAT_RGBA8, data)


## Pixel du sol (coin haut-gauche) de la case (x, z) en unités de monde (multiples de 4).
func ground_px(x: float, z: float) -> Vector2i:
	return Vector2i(int(x * 8.0) + terrain.origin.x, int(z * 8.0) + terrain.origin.y)


## Tuile 32×32 de la texture périodique `tex`, coin haut-gauche au pixel absolu `p` du sol.
static func _sample(tex: PackedByteArray, p: Vector2i) -> PackedByteArray:
	var n := ArtStyle.PERIOD
	var tx := posmod(p.x, n)
	var first := mini(TILE, n - tx) * 4
	var out := PackedByteArray()
	for row in TILE:
		var o := posmod(p.y + row, n) * n * 4
		out.append_array(tex.slice(o + tx * 4, o + tx * 4 + first))
		if first < TILE * 4:
			out.append_array(tex.slice(o, o + TILE * 4 - first))
	return out


## digCell : terre creusée (avec éclats d'ardoise), bords assombris côté roche (bandes '#0008').
func paint_dug_cell(i: int, j: int) -> void:
	# Ordre du prototype : une révélation antérieure est entièrement peinte avant cette case.
	if not _queue.is_empty():
		finish()
	_blit_dug_cell(i, j)
	# Les voisines déjà creusées gardaient leur bande sombre côté nouvelle case : on les repeint.
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if state.dug.has(Vector2i(i, j) + d):
			_blit_dug_cell(i + d.x, j + d.y)


func _blit_dug_cell(i: int, j: int) -> void:
	var x := i * 4.0
	var z := j * 4.0
	var p := ground_px(x, z)
	var out := _sample(_dug_tex[Biomes.rock_tier(z + 2.0)], p)
	terrain.blit(_image(out), p.x, p.y)
	if not state.ground(x - 2.0, z + 2.0):
		terrain.darken(Rect2i(p.x, p.y, 2, TILE))
	if not state.ground(x + 6.0, z + 2.0):
		terrain.darken(Rect2i(p.x + 30, p.y, 2, TILE))
	if not state.ground(x + 2.0, z + 6.0):
		terrain.darken(Rect2i(p.x, p.y + 30, TILE, 2))


## paintRegion : repeint les cases (4×4 unités) de la zone ; roche, sol de grotte et bords.
## Les cases sont mises en file : process() les peint par lots, dans un budget de temps par image
## (une grande galerie coûte plus de 100 ms en GDScript). finish() vide la file immédiatement.
func paint_region(x0: float, z0: float, x1: float, z1: float) -> void:
	stats = {"full": 0, "mixed": 0, "skip": 0}
	var x := x0
	while x < x1:
		var z := z0
		while z < z1:
			_queue.append(Vector2(x, z))
			z += 4.0
		x += 4.0


var _queue: Array[Vector2] = []


func pending() -> int:
	return _queue.size()


## Peint des cases de la file pendant au plus `budget_ms` millisecondes. Renvoie le nombre restant.
func process(budget_ms: float) -> int:
	var deadline := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	while not _queue.is_empty() and Time.get_ticks_usec() < deadline:
		var c: Vector2 = _queue.pop_front()
		_paint_region_cell(c.x, c.y)
	terrain.flush()
	return _queue.size()


## Peint toute la file sans limite de temps (captures, tests, chargement).
func finish() -> void:
	while not _queue.is_empty():
		var c: Vector2 = _queue.pop_front()
		_paint_region_cell(c.x, c.y)
	terrain.flush()


func _paint_region_cell(x: float, z: float) -> bool:
	var any := false
	var all := true
	for o: Vector2 in [Vector2(0, 0), Vector2(4, 0), Vector2(0, 4), Vector2(4, 4), Vector2(2, 2), Vector2(2, 0), Vector2(0, 2), Vector2(4, 2), Vector2(2, 4)]:
		var h := state.hollow(x + o.x, z + o.y)
		any = any or h
		all = all and h
	if not any:
		stats["skip"] += 1
		return false
	stats["full" if all else "mixed"] += 1
	var p := ground_px(x, z)
	var tier := Biomes.rock_tier(z + 2.0)
	var rock_c: Array[PackedByteArray] = _rock_c[tier]
	var cave := _sample(_floor_tex[tier], p)
	var out: PackedByteArray
	if all:
		out = cave
	else:
		var mask := _hollow_mask(x, z)
		out = _sample(_rock_tex[tier], p)
		for py in TILE:
			for px in TILE:
				if mask[(py + 3) * M + px + 3] == 1:
					var o := (py * TILE + px) * 4
					out[o] = cave[o]
					out[o + 1] = cave[o + 1]
					out[o + 2] = cave[o + 2]
					out[o + 3] = 255
		for py in TILE:
			for px in TILE:
				var m := (py + 3) * M + px + 3
				if mask[m] == 1:
					continue
				var o := (py * TILE + px) * 4
				if mask[m + 2 * M] == 1 and mask[m - 3 * M] == 0:
					# Px.dark(…, 0,55) : canal × 0,55 dans un Uint8ClampedArray.
					out[o] = _clamp8(out[o] * 0.55)
					out[o + 1] = _clamp8(out[o + 1] * 0.55)
					out[o + 2] = _clamp8(out[o + 2] * 0.55)
				elif mask[m - 2 * M] == 1:
					_copy(out, o, rock_c[7 if mask[m - M] == 1 else 5])
				elif mask[m - 2] == 1 or mask[m + 2] == 1:
					_copy(out, o, rock_c[0] if mask[m - 1] == 1 or mask[m + 1] == 1 else rock_c[6])
	terrain.blit(_image(out), p.x, p.y)
	return true


## Salle de départ retaillée bloc par bloc (CaveShape.in_cave) : le sol du baker garde le contour du
## prototype. Chaque case de la zone est repeinte d'après la forme réelle : sol, bords, et roche pleine
## là où le prototype avait du sol.
func repaint_cave(x0: float, z0: float, x1: float, z1: float) -> void:
	var z := z0
	while z < z1:
		var x := x0
		while x < x1:
			if not _paint_region_cell(x, z) and _prototype_floor(x, z):
				var p := ground_px(x, z)
				terrain.blit(_image(_sample(_rock_tex[0], p)), p.x, p.y)
			x += 4.0
		z += 4.0
	terrain.flush()


## La case (x, z) touche le sol du prototype (bords compris : 1 unité de marge).
static func _prototype_floor(x: float, z: float) -> bool:
	for a in range(-1, 6):
		for b in range(-1, 6):
			if CaveShape.in_prototype_outline(x + a, z + b):
				return true
	return false


static func _copy(out: PackedByteArray, o: int, c: PackedByteArray) -> void:
	out[o] = c[0]
	out[o + 1] = c[1]
	out[o + 2] = c[2]
	out[o + 3] = 255


## Masque des pixels creux (hol) sur la tuile de la case (x, z) et une marge de 3 px.
## Loin de la salle et du couloir, hol se réduit à « galerie ouverte ou case creusée » : calcul direct
## sur les tableaux, sans appel de fonction par pixel. Sinon, appel de state.hollow (formules exactes).
func _hollow_mask(x: float, z: float) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(M * M)
	# Salle retaillée (CaveShape.in_cave) : parois déplacées jusqu'à |x| < 88, baies nord jusqu'à z −204.
	var near_cave := x + 4.5 > -90.0 and x - 0.5 < 90.0 and z + 4.5 > -206.0 and z - 0.5 < -85.0
	var near_tunnel := x + 4.5 > -CaveShape.CAVE_GATE and x - 0.5 < CaveShape.CAVE_GATE
	if state.breach_open and x + 4.5 > -CaveShape.BREACH_W - 4.0 and x - 0.5 < CaveShape.BREACH_W + 4.0 and z + 4.5 > CaveShape.CAVE_Z1 - 2.0 and z - 0.5 < -70.0:
		near_tunnel = true
	var near_vault := state.vault_open and x + 4.5 > CaveShape.VAULT_X0 and x - 0.5 < CaveShape.VAULT_X1 \
		and z + 4.5 > CaveShape.VAULT_Z0 and z - 0.5 < CaveShape.VAULT_Z1
	if near_cave or near_tunnel or near_vault:
		for py in range(-3, 35):
			for px in range(-3, 35):
				mask[(py + 3) * M + px + 3] = 1 if state.hollow(x + px / 8.0, z + py / 8.0) else 0
		return mask
	var opened := state.found > 0
	var open := state.open
	# Cases creusées voisines (3 × 3) ; la plupart du temps aucune : le test par pixel est alors évité.
	var ci := floori(x / 4.0)
	var cj := floori(z / 4.0)
	var dug := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	var any_dug := false
	for di in range(-1, 2):
		for dj in range(-1, 2):
			if state.dug.has(Vector2i(ci + di, cj + dj)):
				dug[(dj + 1) * 3 + di + 1] = 1
				any_dug = true
	# Colonnes : indice de galerie et case creusée de chaque sous-pixel (constants sur la ligne).
	var col_i := PackedInt32Array()
	var col_d := PackedInt32Array()
	col_i.resize(M)
	col_d.resize(M)
	for px in range(-3, 35):
		var xw := x + px / 8.0
		col_i[px + 3] = floori(xw - CaveShape.WORLD_X0)
		col_d[px + 3] = floori(xw / 4.0) - ci + 1
	var gw := TerrainState.GAL_W
	for py in range(-3, 35):
		var zw := z + py / 8.0
		var j := floori(zw - CaveShape.WORLD_Z0)
		var drow := (floori(zw / 4.0) - cj + 1) * 3
		var base := j * gw
		var row_ok := opened and j >= 0 and j < TerrainState.GAL_H
		var mo := (py + 3) * M
		for c in M:
			var h := 0
			if row_ok:
				var i := col_i[c]
				if i >= 0 and i < gw and open[base + i] == 1:
					h = 1
			if h == 0 and any_dug and dug[drow + col_d[c]] == 1:
				h = 1
			mask[mo + c] = h
	return mask


## Conversion d'un Uint8ClampedArray : arrondi au plus proche, égalités vers le pair.
static func _clamp8(v: float) -> int:
	var f := floorf(v)
	var d := v - f
	var n := int(f) + (1 if d > 0.5 or (d == 0.5 and int(f) % 2 == 1) else 0)
	return clampi(n, 0, 255)
