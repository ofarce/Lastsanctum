class_name MartyreDome
extends Node2D
## Bouclier de la Martyre de Byrsa (sim/martyre.gd) : un mur circulaire d'or du Credo, tramé, qui s'éteint
## vers le haut, avec un liseré doré au sol ponctué de carmin. Deux nœuds : un voile au sol sous les sprites,
## puis le mur (moitié arrière au nord, moitié avant plus pâle au sud) et ses étincelles par-dessus. Le mur s'allume en
## RISE s à l'apparition et s'éteint en clignotant pendant Martyre.COLLAPSE s à la chute. En phase III il se resserre
## (Martyre.radius) : les textures du mur, faites au rayon plein, sont mises à l'échelle autour du centre, et il
## rougeoie tant qu'il se referme.
## Repère : pixels natifs du monde.

## Hauteur du mur, en unités de monde.
const HEIGHT := 6.0
const FRAMES := 4
const FPS := 5.0
const RISE := 1.0
const GOLD := [Color("#a07424"), Color("#d0a038"), Color("#f0cc66"), Color("#fff2b0")]
const CARMINE := Color("#e2382e")
const VEIL := Color(0.82, 0.63, 0.22, 0.07)
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const SPARKS := 90

var world: World
var front := false
static var _tex := {}


func _process(_delta: float) -> void:
	visible = _strength() > 0.0
	if visible:
		queue_redraw()


## 0 : aucun bouclier ; 1 : levé. Montée à l'apparition, extinction clignotante à la chute.
static func _strength() -> float:
	var t := GameState.sim_time
	if Martyre.active():
		return clampf((t - GameState.martyre_at) / RISE, 0.0, 1.0)
	var k := (t - GameState.martyre_down_at) / Martyre.COLLAPSE
	if GameState.martyre_state != "defeated" or k < 0.0 or k >= 1.0:
		return 0.0
	return (1.0 - k) * (1.0 if fmod(t * 14.0, 1.0) < 0.6 else 0.35)


static func radius_px() -> int:
	return roundi(Martyre.RADIUS * Proj.K)


static func height_px() -> int:
	return roundi(HEIGHT * Proj.KH)


## Textures du mur (arrière ou avant), une par image de l'ondulation. Arrière : le haut de l'image est à
## (centre − rayon − hauteur) ; avant : à (centre − hauteur).
static func textures(is_front: bool) -> Array:
	if _tex.has(is_front):
		return _tex[is_front]
	var r := radius_px()
	var hp := height_px()
	var w := 2 * r + 1
	var h := r + hp + 3
	var out: Array = []
	for f in FRAMES:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for x in w:
			var dx := x - r
			var gy := sqrt(maxf(0.0, float(r * r - dx * dx)))
			var ground := roundi(hp + gy) if is_front else roundi(r + hp - gy)
			for k in hp:
				var y := ground - k
				if y < 0 or y >= h:
					continue
				var hh := float(k) / hp
				var band := 0.5 + 0.5 * sin(dx * 0.06 - TAU * f / FRAMES + hh * 5.0)
				var a := pow(1.0 - hh, 1.5) * (0.6 + 0.4 * band) * (0.5 if is_front else 0.8)
				var th: float = (BAYER[y % 4][x % 4] + 0.5) / 16.0
				if a * 2.0 - 1.0 > th:
					img.set_pixel(x, y, Color(GOLD[3] if band > 0.75 else GOLD[2], 0.62))
				elif a * 2.0 > th:
					img.set_pixel(x, y, Color(GOLD[1], 0.34))
			# Liseré au sol : deux pixels d'or, un éclat carmin toutes les 32 colonnes.
			var accent := posmod(dx + f * 4, 32) < 2
			for k in 2:
				var y := ground - k + 1
				if y >= 0 and y < h:
					img.set_pixel(x, y, Color(CARMINE if accent else GOLD[3 - k], 0.9 if k == 0 else 0.6))
		out.append(ImageTexture.create_from_image(img))
	_tex[is_front] = out
	return out


func _draw() -> void:
	var s := _strength()
	if s <= 0.0:
		return
	var c := Proj.nat(GameState.martyre_center.x, 0.0, GameState.martyre_center.y).round()
	var r := radius_px()
	var hp := height_px()
	var t := GameState.sim_time
	var sc := Martyre.radius() / Martyre.RADIUS
	var rc := r * sc
	if not front:
		# Sous les sprites : seulement le voile au sol.
		var pts := PackedVector2Array()
		for k in 64:
			var ang := TAU * k / 64.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * rc)
		draw_colored_polygon(pts, Color(VEIL, VEIL.a * s))
		# Attaques à distance, partie au sol (faille, cercles des sceaux).
		MartyreFx.ground(self)
		return
	# Par-dessus les sprites : le mur est de la lumière, les arbres ne doivent pas le cacher.
	var f := floori(t * FPS) % FRAMES
	var tint := Color(1, 1, 1, s)
	if Martyre.active() and t - GameState.martyre_shrink_at < Martyre.SHRINK:
		var glow := 0.5 + 0.5 * sin(t * 18.0)
		tint = Color(1.0, lerpf(0.75, 0.5, glow), lerpf(0.6, 0.35, glow), s)
	draw_set_transform(c, 0.0, Vector2(sc, sc))
	draw_texture(textures(false)[f], Vector2(-r, -r - hp), tint)
	draw_texture(textures(true)[f], Vector2(-r, -hp), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Étincelles d'or (et quelques carmin) qui montent le long du mur.
	for j in SPARKS:
		var ang := _h(j, 1) * TAU
		var per := 1.6 + _h(j, 2) * 1.8
		var p := fposmod(t + _h(j, 3) * per, per) / per
		var at := (c + Vector2(cos(ang), sin(ang)) * rc + Vector2(0.0, -p * hp * sc * 1.2)).round()
		var col: Color = CARMINE if j % 7 == 0 else GOLD[3]
		draw_rect(Rect2(at, Vector2.ONE), Color(col, sin(PI * p) * s))
	# Attaques à distance, partie lumineuse (éruptions, rai et colonnes des sceaux, étourdissement).
	MartyreFx.air(self)


static func _h(a: int, b: int) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)
