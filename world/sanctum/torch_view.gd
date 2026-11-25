class_name TorchView
extends Node2D
## Torche à bras de fer des couloirs du Temple (planche torches-tunnels-propositions.html, T2 « Bras de fer »),
## dessinée pixel par pixel : platine vissée au mur, bras recourbé, coupelle de fer, flamme animée.
## Enfant d'un Sprite2D vide de SanctumView ; origine au pied de la torche (SanctumLayout._corridor_torches).
## side « n » : sur la face de la paroi nord, au-dessus du pied ; « w » / « e » : contre le rebord ouest / est,
## bras tourné vers le couloir.

## Lumière (halo doux H1, voir SanctumView.lights et lighting_glow.gdshader).
const LIGHT := Color8(208, 144, 64)
const LIGHT_R := 7.0
const GLOW := 0.42
## Hauteur de la platine au-dessus du pied, en pixels, selon le côté.
const MOUNT := {"n": -9, "w": -2, "e": -2}

const INK := Color8(10, 11, 16)
const IRON := [Color8(21, 22, 27), Color8(40, 42, 51), Color8(61, 64, 76), Color8(88, 92, 107), Color8(138, 143, 159)]
## Flamme : pointe rouge → cœur pâle (même palette que la planche).
const FLAME := [Color8(184, 32, 26), Color8(224, 80, 28), Color8(244, 154, 42), Color8(255, 216, 96), Color8(255, 246, 200)]

var side := "n"
var seed := 0.0
static var _arm := {}


func _ready() -> void:
	if side == "e":
		scale.x = -1.0


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _px(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0), c)


## Pixels du support (platine, bras, coupelle), origine à la platine : {Vector2i: Color}.
static func arm() -> Dictionary:
	if not _arm.is_empty():
		return _arm
	var put := func(x: int, y: int, w: int, h: int, c: Color) -> void:
		for j in h:
			for i in w:
				_arm[Vector2i(x + i, y + j)] = c
	put.call(-1, -1, 3, 5, IRON[2])
	put.call(-1, -1, 1, 1, IRON[4])
	put.call(-1, 4, 1, 1, IRON[1])
	put.call(0, -3, 1, 3, IRON[3])
	put.call(1, -4, 1, 1, IRON[3])
	put.call(2, -5, 1, 1, IRON[3])
	put.call(-2, -7, 7, 2, IRON[2])
	put.call(-2, -7, 7, 1, IRON[4])
	put.call(-2, -8, 1, 1, IRON[3])
	put.call(4, -8, 1, 1, IRON[3])
	return _arm


func _draw() -> void:
	var y0: int = MOUNT.get(side, -9)
	var pix := arm()
	# Contour sombre automatique, comme les sprites de la planche.
	for p: Vector2i in pix:
		for o: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not pix.has(p + o):
				_px(p.x + o.x, p.y + o.y + y0, INK)
	for p: Vector2i in pix:
		_px(p.x, p.y + y0, pix[p])
	_flame(1.0, y0 - 8.0)


## Flamme de la planche : 4 à 5 pixels de haut, pointe qui ondule, étincelle de temps en temps.
func _flame(x: float, y: float) -> void:
	var t := GameState.sim_time
	var st := floori(t * 12.0 + seed)
	var h := 4 + (1 if Rng.hash3(st, 5, 0x70c) > 0.55 else 0)
	var sw := sin(t * 6.0 + seed) * 0.9
	for j in h:
		var k := float(j) / h
		var half := 1 if k < 0.65 else 0
		var ox := roundf(sw * k * k)
		for i in range(-half, half + 1):
			var c: Color = FLAME[0] if k > 0.8 else (FLAME[1] if k > 0.55 else FLAME[2])
			if i == 0 and k < 0.45:
				c = FLAME[4] if k < 0.2 else FLAME[3]
			elif absi(i) == 1 and k < 0.25:
				c = FLAME[2]
			_px(x + i + ox, y - j, c)
	if Rng.hash3(st, 9, 0x70c) > 0.7:
		_px(x + roundf(sw) + (1.0 if Rng.hash3(st, 2, 0x70c) > 0.5 else -1.0), y - h - 1, FLAME[0])
