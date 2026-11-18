class_name VineView
extends AmbienceView
## Lisière de la jungle (piste 06) : liane à ressort pendue à une paroi nord, ou grosse racine
## qui perce la paroi et rampe sur le dallage. Origine : pied de la paroi.

const STEM := Color8(74, 106, 50)
const STEM2 := Color8(63, 90, 44)
const LEAF := Color8(108, 138, 74)
const LEAF_HI := Color8(136, 168, 92)
const LEAF_LO := Color8(79, 107, 58)
const FLOWER := Color8(232, 220, 194)
const BARK := Color8(110, 82, 54)
const BARK_M := Color8(87, 64, 42)
const BARK_D := Color8(63, 46, 30)
## Haut de la liane : sous le rebord de la paroi, en pixels relatifs au pied.
const TOP := -30
## Le nœud est trié un peu sous le pied de la paroi : sinon la face de la paroi le recouvre.
const SORT_BIAS := 12.0

var is_root := false
var length := 30


func setup(terrain_state: TerrainState, d: Dictionary, root: bool) -> void:
	place(terrain_state, d)
	is_root = root
	length = d["len"]
	name = ("Root_%d" if root else "Vine_%d") % seed
	position.y += SORT_BIAS


func _draw() -> void:
	draw_set_transform(Vector2(0, -SORT_BIAS))
	if is_root:
		_root()
	else:
		_vine()


func _vine() -> void:
	var tt := t()
	var phase := float(seed % 97)
	var tip := Vector2.ZERO
	for j in length:
		var sw := sin(tt * 1.1 + phase - j * 0.12) * pow(float(j) / length, 1.5) * 5.0
		var p := Vector2(roundf(sw), TOP + j)
		tip = p
		px(p + Vector2(-1, 0), OUT)
		px(p, STEM if j % 7 < 4 else STEM2)
		px(p + Vector2(1, 0), OUT)
		if j % 5 == 2:
			var side := 1 if (j / 5 + seed) % 2 else -1
			var big := h(j, 1) > 0.5
			var leaf: Array = [[1, 0, LEAF], [2, 0, LEAF_HI], [2, -1, LEAF], [3, -1, LEAF_HI], [1, 1, LEAF_LO], [2, 1, LEAF_LO], [3, 0, OUT], [4, -1, OUT], [3, -2, OUT], [2, -2, OUT]] if big \
				else [[1, 0, LEAF], [2, -1, LEAF_HI], [2, 0, OUT], [3, -1, OUT], [1, 1, OUT]]
			for l: Array in leaf:
				px(p + Vector2(l[0] * side, l[1]), l[2])
		if j % 11 == 8 and h(j, 2) > 0.6:
			px(p + Vector2(-2, 0), FLOWER)
			px(p + Vector2(-2, -1), Color8(243, 234, 214))
	px(tip + Vector2(0, 1), LEAF_HI)
	px(tip + Vector2(0, 2), OUT)
	# Une liane sur trois goutte.
	if seed % 3 == 0:
		var per := 2.4 + (seed % 7) * 0.3
		var ph := fmod(tt, per) / per
		var y := tip.y + ph * ph * 40.0
		if y < tip.y + 36:
			px(Vector2(tip.x, y), Color8(169, 189, 214))


func _root() -> void:
	var x := 0.0
	var y := float(TOP + 4)
	var thick := 4.0
	var phase := float(seed % 31)
	for j in length:
		x += sin(j * 0.25 + phase) * 0.6
		y += 1.0
		var w := thick * (1.0 - float(j) / length * 0.75)
		var cw := ceili(w)
		for i in range(-cw, cw + 1):
			var edge := absf(i) >= w - 0.3
			var c := OUT if edge else (BARK if i < 0 else (BARK_M if i < w * 0.4 else BARK_D))
			px(Vector2(x + i, y), c)
		if j % 4 == 0:
			px(Vector2(x, y), Color8(125, 96, 67))
		if j > length / 2 and j % 9 == 0:
			for k in 5:
				px(Vector2(x + w + k, y + k * 0.6), Color8(75, 58, 38))
	for k in 6:
		px(Vector2(x - 3 + k, y + 1), BARK_D)
		px(Vector2(x - 4 + k * 1.6, y + 2), OUT)
	# Dalles soulevées au pied.
	for i in 3:
		var p := Vector2(roundf(x) - 8 + i * 6, roundf(y) - 1 + roundf(h(i, 7) * 3.0))
		draw_rect(Rect2(p, Vector2(4, 2)), Color8(85, 93, 107))
		draw_rect(Rect2(p + Vector2(0, 2), Vector2(4, 1)), OUT)
		draw_rect(Rect2(p + Vector2(0, -1), Vector2(4, 1)), OUT)
