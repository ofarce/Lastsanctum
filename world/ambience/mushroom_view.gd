class_name MushroomView
extends AmbienceView
## Touffe de champignons luminescents (piste 03) : grappe ivoire, parfois une paire de lanternes
## (avec papillons de nuit) ou une vesse-de-loup qui crache ses spores au passage.

const STEM := Color8(207, 200, 176)
const STEM2 := Color8(168, 159, 134)
const CAP := Color8(216, 230, 196)
const CAP_HI := Color8(246, 251, 233)
const GILL := Color8(159, 179, 140)
const GILL_D := Color8(111, 128, 95)
const SPORE := Color8(234, 245, 216)
const LIGHT := Color8(220, 240, 205)

var lantern := false
var puff := false
var _caps: Array = []
var _burst := -1.0
var _cool := 0.0


func setup(terrain_state: TerrainState, d: Dictionary) -> void:
	place(terrain_state, d)
	lantern = d["lantern"]
	puff = d["puff"]
	name = "Mushrooms_%d" % seed
	var n := 3 + floori(h(0, 1) * 3.0)
	for i in n:
		_caps.append([roundi((h(i, 2) - 0.5) * 14.0), roundi(h(i, 3) * 4.0), 3 + floori(h(i, 4) * 5.0), 1 + floori(h(i, 5) * 3.0)])


## Pulsation : la phase dépend de x, la lumière court le long des galeries.
func pulse() -> float:
	return 0.5 + 0.5 * sin(t() * 2.0 - wx * 0.32)


func tick() -> void:
	if puff:
		if _burst >= 0.0:
			_burst += get_process_delta_time()
			if _burst > 1.2:
				_burst = -1.0
				_cool = 8.0
		elif _cool > 0.0:
			_cool -= get_process_delta_time()
		elif nearest_unit() < 2.5:
			_burst = 0.0


func _draw() -> void:
	var k := pulse()
	for c: Array in _caps:
		_cap(Vector2(c[0], c[1]), c[2], c[3], k)
	if lantern:
		for i in 2:
			_lantern(Vector2(9 + i * 5, 2 - i * 3), 8 + i * 3, k, sin(t() * 1.3 + i) * 0.5)
		for m in 2:
			var a := t() * (1.8 + m * 0.4) + m * 2.0
			var p := Vector2(11 + cos(a) * 9.0, -16 + sin(a * 1.4) * 5.0)
			var f := int(t() * 14.0 + m) % 2
			px(p, Color8(107, 97, 80))
			if f:
				px(p + Vector2(-1, 0), Color8(232, 224, 204))
				px(p + Vector2(1, 0), Color8(232, 224, 204))
			else:
				px(p + Vector2(-1, -1), Color8(163, 154, 134))
				px(p + Vector2(1, -1), Color8(163, 154, 134))
	if puff:
		_puffball(Vector2(-11, 3))
	for i in 8:
		var life := fmod(t() * 0.2 + h(i, 9), 1.0)
		var a := sin(life * PI) * 0.8
		var p := Vector2(sin(t() * 0.9 + i) * 8.0 * life, -8.0 - life * 36.0)
		px(p, Color(SPORE, a))


func _cap(at: Vector2, hgt: int, w: int, k: float) -> void:
	for j in hgt:
		px(at + Vector2(0, -j), STEM)
		px(at + Vector2(-1, -j), OUT)
		px(at + Vector2(1, -j), STEM2)
	var cy := at.y - hgt
	for i in range(-w, w + 1):
		var e := 1.0 - pow(float(i) / w, 2.0)
		var hh := maxi(1, roundi(e * w * 0.7))
		for j in hh:
			var c := OUT if j == hh - 1 else CAP.lerp(CAP_HI, k * 0.6 * float(j) / hh)
			px(Vector2(at.x + i, cy - j), c)
		px(Vector2(at.x + i, cy + 1), GILL if absi(i) < w else OUT)
	for s: int in [-1, 1]:
		px(Vector2(at.x + s * (w + 1), cy), OUT)
		px(Vector2(at.x + s * w, cy + 1), OUT)
	for i in range(-w + 1, w, 2):
		px(Vector2(at.x + i, cy + 1), GILL_D)


func _lantern(at: Vector2, hgt: int, k: float, sw: float) -> void:
	for j in hgt:
		var x := at.x + roundf(sin(sw) * j / hgt * 2.0)
		px(Vector2(x, at.y - j), Color8(154, 165, 138))
		px(Vector2(x - 1, at.y - j), OUT)
	var b := Vector2(at.x + roundf(sin(sw) * 2.0), at.y - hgt)
	var pal := {"X": OUT, "b": Color8(191, 224, 200).lerp(Color.WHITE, k * 0.4), "w": Color8(232, 255, 240).lerp(Color.WHITE, k)}
	spr([".XXX.", "XbwbX", "XwwwX", "XbwbX", ".XXX."], b + Vector2(-2, -4), pal)


func _puffball(at: Vector2) -> void:
	var squash := _burst >= 0.0 and _burst < 0.2
	var pal := {"X": OUT, "p": Color8(183, 176, 154), "q": Color8(228, 222, 200)}
	if squash:
		spr([".XXXXX.", "XpppppX", "XpqpppX", "XXXXXXX"], at + Vector2(-3, -3), pal)
	else:
		spr(["..XXX..", ".XpqpX.", "XppqppX", "XpppppX", ".XXXXX."], at + Vector2(-3, -4), pal)
	if _burst >= 0.0:
		var b := _burst / 1.2
		for i in 22:
			var a := h(i, 11) * TAU
			var r := b * (8.0 + h(i, 12) * 10.0)
			px(at + Vector2(cos(a) * r, -4.0 - absf(sin(a)) * r * 0.8 - b * 6.0), Color(SPORE, (1.0 - b) * 0.9))
