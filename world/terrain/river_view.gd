class_name RiverView
extends Node2D
## Rendu de la rivière (River) : bandes de SEG unités, chacune deux sprites posés au sol sous les objets
## triés : l'eau (river.gdshader, animée) puis les berges et les ponts de pierre (image fixe).

const SHADER := preload("res://shaders/river.gdshader")
const PX := 8
const SEG := 128
## Portée de la crue codée dans B (unités au-delà de la berge).
const FLOOD_RANGE := 8.0

const OUTLINE := Color8(38, 44, 30)
const MUD := Color8(92, 78, 54)
const SAND := Color8(150, 128, 86)
const SAND_LIGHT := Color8(176, 154, 104)
const STONE := [Color8(132, 126, 112), Color8(120, 115, 103), Color8(144, 138, 121), Color8(112, 110, 99)]
const MORTAR := Color8(78, 74, 66)
const MOSS := Color8(88, 108, 64)
const CAP := Color8(168, 161, 142)
const CAP_DARK := Color8(58, 56, 50)

## Graine de rivière → bandes [px0, py0, texture d'eau, texture des berges] ; quelques graines au plus.
const CACHE_SIZE := 4
static var _cache := {}

var river: River
var _mats: Array[ShaderMaterial] = []


func setup(r: River) -> void:
	river = r
	name = "River"
	for child in get_children():
		child.free()
	_mats.clear()
	var zr := river.z_range()
	var py0 := floori(zr.x * PX)
	var h := ceili(zr.y * PX) - py0
	# Les images ne dépendent que de la graine de la rivière : calculées une fois (boucle par pixel,
	# plusieurs secondes), puis reprises à chaque nouvelle partie de même graine (tests, Recommencer).
	var segs: Array = _cache.get(river.seed, [])
	if segs.is_empty():
		var x := CaveShape.WORLD_X0
		while x < CaveShape.WORLD_X1:
			var px0 := floori(x * PX)
			segs.append([px0, py0] + _segment_textures(px0, py0, mini(SEG * PX, floori((CaveShape.WORLD_X1 - x) * PX)), h))
			x += SEG
		if _cache.size() >= CACHE_SIZE:
			_cache.erase(_cache.keys()[0])
		_cache[river.seed] = segs
	for s: Array in segs:
		_add_segment(s[0], s[1], s[2], s[3])


## Crue (unités au-delà des berges) affichée par l'eau.
func set_flood(units: float) -> void:
	for m in _mats:
		m.set_shader_parameter("flood", clampf(units / FLOOD_RANGE, 0.0, 1.0))


## Textures [eau, berges] d'une bande.
func _segment_textures(px0: int, py0: int, w: int, h: int) -> Array:
	var water := PackedByteArray()
	water.resize(w * h * 4)
	var top := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for i in w:
		var wx := (px0 + i + 0.5) / PX
		var c := river.center(wx)
		var hw := river.half_width(wx)
		var b := river.bridge_near(wx)
		var j0 := 0
		var j1 := h
		if b.is_empty():
			j0 = maxi(0, floori((c - hw - FLOOD_RANGE) * PX) - py0)
			j1 = mini(h, ceili((c + hw + FLOOD_RANGE) * PX) - py0)
		for j in range(j0, j1):
			var wz := (py0 + j + 0.5) / PX
			var d := absf(wz - c) - hw
			# Banc de sable au milieu d'une mare : berge dans l'eau (River.bank_distance).
			if d < 0.0 and not river.bars.is_empty():
				d = river.bank_distance(wx, wz)
			var k := (j * w + i) * 4
			if d < 0.0:
				water[k] = int(clampf(-d / maxf(hw, 0.5), 0.0, 1.0) * 255.0)
				water[k + 1] = int(_rapids(wx, d, hw) * 255.0)
				water[k + 3] = 255
			elif d < FLOOD_RANGE and absf(wz - c) < hw:
				# Banc de sable : noyé dès la première crue.
				water[k + 2] = 1
			elif d < FLOOD_RANGE and (b.is_empty() or wz < float(b["z0"]) - 0.5 or wz >= float(b["z1"]) + 0.5):
				water[k + 2] = maxi(1, int(d / FLOOD_RANGE * 255.0))
			var col := _bank(px0 + i, py0 + j, d)
			if not b.is_empty():
				var bc := _bridge(b, wx, wz, px0 + i, py0 + j)
				if bc.a > 0.0:
					col = bc
			if col.a > 0.0:
				top.set_pixel(i, j, col)
	var data := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, water)
	return [ImageTexture.create_from_image(data), ImageTexture.create_from_image(top)]


func _add_segment(px0: int, py0: int, water_tex: Texture2D, top_tex: Texture2D) -> void:
	var ws := Sprite2D.new()
	ws.centered = false
	ws.position = Vector2(px0, py0)
	ws.texture = water_tex
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("origin", Vector2(px0, py0))
	ws.material = m
	_mats.append(m)
	add_child(ws)
	var ts := Sprite2D.new()
	ts.centered = false
	ts.position = Vector2(px0, py0)
	ts.texture = top_tex
	add_child(ts)
	# Crue : l'eau qui déborde passe par-dessus les berges.
	var fs := Sprite2D.new()
	fs.centered = false
	fs.position = ws.position
	fs.texture = ws.texture
	var fm := ShaderMaterial.new()
	fm.shader = SHADER
	fm.set_shader_parameter("origin", Vector2(px0, py0))
	fm.set_shader_parameter("flood_only", true)
	fs.material = fm
	_mats.append(fm)
	add_child(fs)


## Écume : contre les piles des ponts (en aval, à l'est) et là où le lit se resserre.
func _rapids(wx: float, d: float, hw: float) -> float:
	var f := clampf((2.9 - hw) / 1.2, 0.0, 0.3) * clampf(-d / hw * 2.0, 0.0, 1.0)
	for b in river.bridges:
		var dx := wx - float(b["x"])
		var edge := River.DECK_HALF + River.PARAPET
		if dx > edge and dx < edge + 3.0:
			f = maxf(f, 1.0 - (dx - edge) / 3.0)
		elif dx < -edge and dx > -edge - 0.6:
			f = maxf(f, 0.35)
	return f


## Berge : liseré sombre au bord de l'eau, vase puis sable tramé, fondu dans l'herbe.
func _bank(px: int, py: int, d: float) -> Color:
	if d < -0.12:
		return Color(0, 0, 0, 0)
	var n := Rng.hash3(px, py, river.seed)
	if d < 0.15:
		return OUTLINE
	if d < 0.55:
		return MUD
	if d < River.BANK:
		var t := (d - 0.55) / (River.BANK - 0.55)
		if n < 0.08:
			return SAND_LIGHT
		return SAND if n > t * 0.7 else MUD
	if d < River.BANK + 0.6:
		# Tramage sable → herbe.
		var t := (d - River.BANK) / 0.6
		if n > t + 0.35:
			return SAND
	return Color(0, 0, 0, 0)


## Pont de pierre ancien : tablier en moellons décalés, mousse, parapets à couronnement clair.
func _bridge(b: Dictionary, wx: float, wz: float, px: int, py: int) -> Color:
	var z0: float = b["z0"]
	var z1: float = b["z1"]
	if wz < z0 or wz >= z1:
		# Ombre portée au sud du pont, sur l'eau.
		var dx := absf(wx - float(b["x"]))
		if wz >= z1 and wz < z1 + 0.5 and dx < River.DECK_HALF + River.PARAPET and river.water_at(wx, wz):
			return Color(0.05, 0.08, 0.06, 0.45)
		return Color(0, 0, 0, 0)
	var dx := absf(wx - float(b["x"]))
	var outer := River.DECK_HALF + River.PARAPET
	if dx >= outer:
		return Color(0, 0, 0, 0)
	var lx := px - floori((float(b["x"]) - outer) * PX)
	var ly := py - floori(z0 * PX)
	var lh := floori((z1 - z0) * PX)
	var n := Rng.hash3(px, py, river.seed ^ 0xb21d)
	# Parapets.
	if dx >= River.DECK_HALF:
		var edge := outer - dx
		if edge < 1.0 / PX or ly == 0 or ly >= lh - 1:
			return CAP_DARK
		if dx < River.DECK_HALF + 1.0 / PX:
			return CAP_DARK
		if n < 0.12:
			return MOSS
		return CAP if (ly / 4) % 2 == 0 or edge > 2.5 / PX else STONE[0]
	# Marches aux extrémités du tablier.
	if ly < 2 or ly >= lh - 2:
		return MORTAR if ly == 0 or ly == lh - 1 else STONE[3]
	# Moellons de 6 × 4 px en rangs décalés.
	var row := ly / 4
	var bxp := (lx + (3 if row % 2 else 0)) / 6
	if ly % 4 == 0 or (lx + (3 if row % 2 else 0)) % 6 == 0:
		return MORTAR
	var stone_n := Rng.hash3(bxp, row, int(b["x"]) + river.seed)
	if n < 0.05 + 0.15 * clampf(1.0 - (River.DECK_HALF - dx) / 1.2, 0.0, 1.0):
		return MOSS
	return STONE[floori(stone_n * STONE.size()) % STONE.size()]
