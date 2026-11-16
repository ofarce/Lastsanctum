class_name SoulwellHalo
extends Node2D
## Halo du Puits des Âmes (planche « Puits des Âmes · Lotus de pierre ») : une lueur verte diffuse, tramée,
## sans bord net, couvre au sol la zone de soin (heal_radius) de chaque puits achevé ; elle respire avec les
## pétales du Lotus (boucle de 6 s) et quelques spores y dérivent. Dessiné sous les sprites, comme BuildGrid.
## Repère : pixels natifs du monde.

const BREATH_FRAMES := 6
const LOOP := 6.0
const TINT := Color(0.478, 0.878, 0.439)
const SPORES := 18
const SPORE := [Color("#7ae070"), Color("#b8f0a0")]
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

var world: World
static var _frames: Array[ImageTexture] = []
static var _radius := 0


func _process(_delta: float) -> void:
	queue_redraw()


## Textures tramées du halo, une par palier de respiration.
static func frames(radius_px: int) -> Array[ImageTexture]:
	if _radius == radius_px and not _frames.is_empty():
		return _frames
	_radius = radius_px
	_frames.clear()
	var n := radius_px * 2 + 1
	for f in BREATH_FRAMES:
		var breath := 0.5 - 0.5 * cos(TAU * f / BREATH_FRAMES)
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x - radius_px, y - radius_px).length() / radius_px
				if d >= 1.0:
					continue
				# Deux paliers d'intensité, tramés (Bayer 4×4), qui s'éteignent vers le bord.
				var i := pow(1.0 - d, 0.8) * (0.62 + 0.1 * breath)
				var th: float = (BAYER[y % 4][x % 4] + 0.5) / 16.0
				var lv := 0
				if i * 2.0 > th:
					lv = 1
				if i * 2.0 - 1.0 > th:
					lv = 2
				if lv > 0:
					img.set_pixel(x, y, Color(TINT, 0.09 if lv == 1 else 0.18))
		_frames.append(ImageTexture.create_from_image(img))
	return _frames


func _draw() -> void:
	var t := GameState.sim_time
	for b: Building in GameState.buildings:
		if b.type != "soulwell" or not b.complete:
			continue
		var r := int(roundf(float(b.def()["heal_radius"]) * Proj.K))
		var tex := frames(r)
		var ph := 0.5 - 0.5 * cos(TAU * fposmod(t, LOOP) / LOOP)
		var c := Proj.nat(b.x, 0.0, b.z).round()
		draw_texture(tex[mini(BREATH_FRAMES - 1, floori(ph * BREATH_FRAMES))], c - Vector2(r, r))
		# Spores qui dérivent et montent doucement dans le halo.
		for j in SPORES:
			var per := 4.0 + _h(j, 1) * 3.0
			var p := fposmod(t + _h(j, 2) * per, per) / per
			var a := _h(j, 3) * TAU
			var dd := (0.2 + _h(j, 4) * 0.72) * r
			var at := (c + Vector2(cos(a) * dd + sin(p * 5.0 + j) * 2.0, sin(a) * dd - p * 10.0)).round()
			var al := sin(PI * p)
			if al * 0.9 > (BAYER[posmod(int(at.y), 4)][posmod(int(at.x), 4)] + 0.5) / 16.0:
				draw_rect(Rect2(at, Vector2.ONE), SPORE[1] if p > 0.3 and p < 0.6 else SPORE[0])


static func _h(a: int, b: int) -> float:
	var s := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return s - floorf(s)
