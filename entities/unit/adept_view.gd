class_name AdeptView
extends Node2D
## Rendu d'un adepte (drawAdept, adepts.js, 73b410f) : ombre, sélection, personnage des bâtiments agrandi
## ×1,9 (repos, marche sur 2 images, travail sur 4 images à 6 im/s), orientation, barre de vie quand
## l'adepte est blessé, badge de niveau (★n) à partir du niveau 2.
## Origine : point au sol, sans arrondi (le prototype dessine à la position projetée exacte).

## Z()/16 × 1,9 en pixels natifs.
const SCALE := 8.0 / 0.86 / 16.0 * 1.9
const ZN := 8.0 / 0.86
const SHADOW := Color("#0b1615a0")
const SEL := Color("#ead08c55")

static var _meta: Dictionary
## Caisse portée (production_crate.png) et couleurs des objets transportés (matériaux, objets fabriqués).
static var _crate: Texture2D
const _ITEMS_A := preload("res://data/mineable_blocks.gd").ITEMS
const _ITEMS_B := preload("res://data/recipes.gd").ITEMS

var unit: Unit
var world: World
var _frames := {}
var _ax := 0.0
var _ay := 0.0
var _lx := NAN
var _lz := NAN
var _face := 1
var _moving := false
var _bold: FontVariation
var _key: Array = []
var _revive: ReviveFx


func setup(u: Unit, w: World) -> void:
	unit = u
	world = w
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["adepts"]["roles"]
	var R: Dictionary = _meta[u.role]
	_ax = R["ax"]
	_ay = R["ay"]
	for mode: String in R["modes"]:
		var m: Dictionary = R["modes"][mode]
		var tex: Texture2D = load("res://assets/baked/adepts/%s_%s.png" % [u.role, mode])
		var list: Array[Rect2] = []
		for i in int(m["count"]):
			list.append(Rect2((i % int(m["cols"])) * float(m["frame_w"]), (i / int(m["cols"])) * float(m["frame_h"]), m["frame_w"], m["frame_h"]))
		_frames[mode] = {"tex": tex, "rects": list}
	_bold = FontVariation.new()
	_bold.base_font = load("res://assets/fonts/DejaVuSans.ttf")
	_bold.variation_embolden = 0.7
	# L'effet est un calque enfant : le rendu standard de l'adepte reste intact.
	_revive = ReviveFx.new()
	_revive.view = self
	_revive.scale = Vector2(SCALE, SCALE)
	add_child(_revive)
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var u := unit
	visible = not u.hidden and u.alive()
	if _revive:
		_revive.tick()
	position = Proj.nat(u.x, 0.0, u.z)
	if is_nan(_lx):
		_lx = u.x
		_lz = u.z
	_moving = Vector2(u.x - _lx, u.z - _lz).length() > 0.001
	if absf(u.x - _lx) > 0.001:
		_face = -1 if u.x < _lx else 1
	elif u.face != 0 and u.attack > 0.0:
		# Orientation imposée par la dernière frappe (u._face).
		_face = u.face
	_lx = u.x
	_lz = u.z
	# Redessin seulement si l'image, l'orientation, la sélection, les PV, le niveau ou PX changent.
	var key := [_mode(), _frame_index(), _face, GameState.selected.has(u), u.hp, u.max_hp, Catalog.lvl(u),
		world.camera.px if world else 1, u.carrying.get("item", "")]
	if key != _key:
		_key = key
		queue_redraw()


func _draw() -> void:
	var u := unit
	_ellipse(0.7, SHADOW)
	if GameState.selected.has(u):
		_ellipse(1.45, SEL)
	var mode := _mode()
	var F: Dictionary = _frames[mode]
	var rects: Array[Rect2] = F["rects"]
	var i := _frame_index()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE * _face, SCALE))
	draw_texture_rect_region(F["tex"], Rect2(-_ax, -_ay, rects[i].size.x, rects[i].size.y), rects[i])
	if not u.carrying.is_empty():
		_draw_crate(String(u.carrying["item"]))
	# Barre de vie et badge : pixels d'écran, au-dessus de la tête (project(x, 3,9, z)).
	var px := float(world.camera.px) if world else 1.0
	var head := Proj.nat(u.x, 3.9, u.z) - position
	draw_set_transform(head, 0.0, Vector2(1.0 / px, 1.0 / px))
	if u.hp < u.max_hp:
		draw_rect(Rect2(-12, 0, 24, 3), Color("#000000aa"))
		draw_rect(Rect2(-12, 0, 24.0 * u.hp / u.max_hp, 3), Color("#8fd16a"))
	var lvl := Catalog.lvl(u)
	if lvl >= 2:
		var text := "★%d" % lvl
		var w := _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(_bold, Vector2(-w / 2.0 + 1.0, -3.0 + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#0b0a09cc"))
		draw_string(_bold, Vector2(-w / 2.0, -3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffe08a"))
	draw_set_transform(Vector2.ZERO)


## Port 2 retenu (planches/coffres-production-propositions.html) : caisse tenue à deux mains devant le ventre, le lot
## visible dessus (trois éclats de la couleur de l'objet). Dessinée dans le repère du personnage (×SCALE).
func _draw_crate(item: String) -> void:
	if _crate == null:
		_crate = load("res://assets/baked/world/production_crate.png")
	var c: Color = _ITEMS_A.get(item, _ITEMS_B.get(item, {})).get("color", Color("#9da2a9"))
	var top := Vector2(-6.0, -_ay + 13.0)
	draw_texture(_crate, top)
	for k in 3:
		var p := top + Vector2(3.0 + k * 2.0, 0.0 - (k % 2))
		draw_rect(Rect2(p, Vector2(2, 1)), c.darkened(0.25))
		draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 1)), c.lightened(0.25))


func _mode() -> String:
	var busy := unit.working or Combat.fight_busy(unit)
	return "walk" if _moving else ("work" if busy else "idle")


func _frame_index() -> int:
	var mode := _mode()
	var t := GameState.sim_time + unit.id * 0.37
	var i := 0
	if mode == "walk":
		i = floori(t * 6.0) & 1
	elif mode == "work":
		i = floori(t * 6.0) & 3
	var rects: Array[Rect2] = _frames[mode]["rects"]
	return mini(i, rects.size() - 1)


## circle3 : ellipse au sol de rayon r unités (r·Z·0,9 sur r·Z·0,42), inclinée de −0,02 rad.
func _ellipse(r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for k in 40:
		var a := TAU * k / 40.0
		pts.append(Vector2(cos(a) * r * ZN * 0.9, sin(a) * r * ZN * 0.42).rotated(-0.02))
	draw_colored_polygon(pts, c)
