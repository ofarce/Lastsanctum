class_name GroveView
extends Node2D
## Bosquet pétrifié posé au sol (2 × 2 cases, planche bosquet-feuilles-propositions.html, piste 2.2) :
## sprite selon le bois restant, flaque de lumière au sol et rai tombant d'une fissure du plafond.
## Origine du nœud : milieu du bord bas de l'emprise (tri en profondeur avec les unités).

const SPRITES := preload("res://assets/ardoise/world/bosquet.png")
const Blocks := preload("res://data/mineable_blocks.gd")
## bosquet.png : 5 états d'usure de 96 × 104 px ; l'emprise (64 × 64) commence en (16, 40).
const FRAME := Vector2(96, 104)
const STAGES := 5
const BEAM := Color(1.0, 0.945, 0.82)
## Rai : haut (fissure) et flaque au sol, en pixels relatifs au nœud.
const BEAM_TOP := Vector2(32, -136)
const BEAM_TOP_HW := 9.0
const POOL := Vector2(0, -30)
const POOL_R := Vector2(46, 24)

var state: TerrainState
var origin: Vector2i
var _pool := Node2D.new()
var _beam := Node2D.new()
var _stage := -1


func setup(terrain_state: TerrainState, key: Vector2i) -> void:
	state = terrain_state
	origin = key
	name = "Grove_%d_%d" % [key.x, key.y]
	position = Vector2(key.x * 32 + 32, key.y * 32 + 64)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_pool.material = add
	_pool.show_behind_parent = true
	_pool.draw.connect(_draw_pool)
	add_child(_pool)
	_beam.material = add
	_beam.draw.connect(_draw_beam)
	add_child(_beam)


## Indice d'usure : 0 = intact (20 bois), 4 = souches.
func stage() -> int:
	var left: int = state.wood_left.get(origin, 0)
	return clampi(roundi((1.0 - float(left) / Blocks.WOOD_YIELD) * (STAGES - 1)), 0, STAGES - 1)


func _process(_delta: float) -> void:
	if not state.wood_left.has(origin):
		queue_free()
		return
	var s := stage()
	if s != _stage:
		_stage = s
		queue_redraw()
	_pool.queue_redraw()
	_beam.queue_redraw()


func _draw() -> void:
	draw_texture_rect_region(SPRITES, Rect2(Vector2(-48, -104), FRAME), Rect2(Vector2(_stage * FRAME.x, 0), FRAME))


func _pulse() -> float:
	var t := GameState.sim_time
	return 0.35 * sin(t * 1.3) + 0.15 * sin(t * 3.1)


## Flaque au sol : trois paliers d'ellipses, plus marqués au centre.
func _draw_pool() -> void:
	var k := 1.0 + _pulse() * 0.4
	for band in 3:
		var f := 1.0 - band * 0.28
		_ellipse(_pool, POOL, POOL_R * f, Color(BEAM, 0.06 * k))


## Volume du rai : trapèzes emboîtés (paliers) et poussières qui descendent dans la lumière.
func _draw_beam() -> void:
	var k := 1.0 + _pulse() * 0.4
	for band in 3:
		var f := 1.0 - band * 0.3
		var top := BEAM_TOP_HW * f
		var bottom := POOL_R.x * 0.85 * f
		_beam.draw_colored_polygon(PackedVector2Array([
			BEAM_TOP + Vector2(-top, 0), BEAM_TOP + Vector2(top, 0),
			POOL + Vector2(bottom, 0), POOL + Vector2(-bottom, 0)]), Color(BEAM, 0.06 * k))
	var t := GameState.sim_time
	var h := POOL.y - BEAM_TOP.y
	for i in 18:
		var a := Rng.hash3(i, origin.x, origin.y)
		var y := fmod(a * h + t * (4.0 + Rng.hash3(i, 4, origin.y) * 5.0), h)
		var f := y / h
		var cx := lerpf(BEAM_TOP.x, POOL.x, f)
		var hw := lerpf(BEAM_TOP_HW, POOL_R.x * 0.85, f)
		var x := cx + (Rng.hash3(i, 5, origin.x) * 2.0 - 1.0) * hw * 0.75 + sin(t + i) * 1.5
		if sin(t * 2.0 + i * 1.7) > -0.2:
			_beam.draw_rect(Rect2(Vector2(roundf(x), roundf(BEAM_TOP.y + y)), Vector2.ONE), Color(BEAM, 0.7))


static func _ellipse(canvas: CanvasItem, c: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	canvas.draw_colored_polygon(pts, color)
