class_name AmbienceView
extends Node2D
## Base des ambiances de la montagne : n'apparaît que dans une galerie ouverte, ne se redessine
## qu'à l'écran. Dessin pixel par pixel en coordonnées natives (1 unité = 8 px).

const OUT := Color8(11, 9, 11)
## Marge de visibilité, en pixels natifs.
const MARGIN := 80.0

var state: TerrainState
var wx := 0.0
var wz := 0.0
var seed := 0


func place(terrain_state: TerrainState, d: Dictionary) -> void:
	state = terrain_state
	wx = d["x"]
	wz = d["z"]
	seed = d.get("seed", 0)
	position = Vector2(roundf(wx * 8.0), roundf(wz * 8.0))
	visible = false


func _process(_delta: float) -> void:
	var show := state != null and state.is_gallery_open(wx, wz) and _on_screen()
	visible = show
	if show:
		tick()
		queue_redraw()


## Mise à jour propre à l'ambiance (appelée seulement quand elle est visible).
func tick() -> void:
	pass


func _on_screen() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var p := get_global_transform_with_canvas().origin
	var r := vp.get_visible_rect().grow(MARGIN * get_global_transform_with_canvas().get_scale().x)
	return r.has_point(p)


func t() -> float:
	return GameState.sim_time


func px(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(Vector2(roundf(p.x), roundf(p.y)), Vector2.ONE), c)


## Sprite en caractères (« . » = vide).
func spr(rows: Array, at: Vector2, pal: Dictionary, flip := false) -> void:
	for j in rows.size():
		var row: String = rows[j]
		var w := row.length()
		for i in w:
			var ch := row[w - 1 - i] if flip else row[i]
			if ch != "." and pal.has(ch):
				px(at + Vector2(i, j), pal[ch])


## Unité vivante la plus proche (en unités), ou INF.
func nearest_unit() -> float:
	var best := INF
	for u in GameState.units:
		if u.alive() and not u.hidden:
			best = minf(best, Vector2(u.x - wx, u.z - wz).length())
	return best


func h(i: int, j: int) -> float:
	return Rng.hash3(i, j, seed)
