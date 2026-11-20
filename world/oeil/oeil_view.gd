class_name OeilView
extends Node2D
## L'Œil de la Matrice (sim/oeil.gd), piste « L'Orbite », en trois calques exportés par
## planches/oeil-matrice-export.html (assets/imported/oeil/), chacun décliné par phase (blanc injecté, iris fendu,
## paupière fendue en III) : le corps (boucle de repos, ou boucle de tir pendant une attaque), l'iris décalé vers le
## regard (GameState.oeil_run.look) et dilaté avec l'ouverture (orbite vide pendant les Pupilles errantes), puis les
## paupières à l'ouverture courante. Il rougit un instant quand il est touché ; à sa mort il pâlit, s'affaisse et
## s'efface en OeilMatrice.COLLAPSE s.
## Enfant de YSort, trié sur le centre de sa base.

const DIR := "res://assets/imported/oeil/"
## Ouverture minimale des paupières (œil mi-clos au repos), comme sur la planche (oeil.json : eye.rest_open).
const REST_OPEN := 0.22
static var _meta: Dictionary
static var _tex: Dictionary

var enemy: Enemy
var world: World
var _body := Sprite2D.new()
var _iris := Sprite2D.new()
var _lids := Sprite2D.new()
var _dark := 0.0


static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "oeil.json"))
		for ph in int(_meta.get("phases", 1)):
			for k: String in ["idle", "cast"]:
				_tex["%s_%d" % [k, ph]] = load(DIR + "oeil_%s_p%d.png" % [k, ph])
		for k: String in ["iris", "lids"]:
			_tex[k] = load(DIR + "oeil_%s.png" % k)
	return _meta


func setup(e: Enemy, w: World) -> void:
	enemy = e
	world = w
	name = "OeilMatrice"
	var m := meta()
	for s: Sprite2D in [_body, _iris, _lids]:
		s.centered = false
		s.region_enabled = true
		s.use_parent_material = true
		add_child(s)
	_body.offset = -Vector2(float(m["ax"]), float(m["ay"]))
	_iris.texture = _tex["iris"]
	_lids.texture = _tex["lids"]
	_process(0.0)


func _process(delta: float) -> void:
	if enemy == null:
		return
	var m := _meta
	var t := GameState.sim_time
	position = Proj.nat(enemy.x, 0.0, enemy.z).round()
	visible = world == null or world.fog.visible_at(enemy.pos())
	var r := OeilMatrice.run()
	var open: float = r.get("open", 0.0)
	var ph: int = clampi(int(r.get("phase", 0)), 0, int(m.get("phases", 1)) - 1)
	var sheet := "cast" if open > 0.5 and enemy.hp > 0.0 else "idle"
	var bm: Dictionary = m[sheet]
	_body.texture = _tex["%s_%d" % [sheet, ph]]
	var f := floori(t * float(bm["fps"])) % int(bm["count"])
	_body.region_rect = _cell(bm, f)
	# Iris : course limitée pour rester dans le globe, dilatation avec l'ouverture.
	var eye: Dictionary = m["eye"]
	var look: float = r.get("look", PI / 2.0)
	var anchor := Vector2(float(m["ax"]), float(m["ay"]))
	var c := Vector2(float(eye["x"]), float(eye["y"])) - anchor
	var im: Dictionary = m["iris"]
	var fi := int(im["socket"]) if r.get("iris_out", false) else clampi(roundi(open * (int(im["count"]) - 1)), 0, int(im["count"]) - 1)
	_iris.region_rect = _cell(im, fi, ph)
	_iris.position = (c + Vector2(cos(look) * float(eye["look_x"]), sin(look) * float(eye["look_y"])) - Vector2(float(im["cx"]), float(im["cy"]))).round()
	var lm: Dictionary = m["lids"]
	var dead := enemy.hp <= 0.0
	var rest: float = float(eye.get("rest_open", REST_OPEN)) * (0.0 if r.get("close", false) else 1.0)
	var lo := 0.0 if dead else rest + (1.0 - rest) * open
	_lids.region_rect = _cell(lm, clampi(roundi(lo * (int(lm["count"]) - 1)), 0, int(lm["count"]) - 1), ph)
	_lids.position = (c - Vector2(float(lm["cx"]), float(lm["cy"]))).round()
	# Touché : il rougit ; mort : il pâlit, s'affaisse et s'efface.
	# Clignement : la masse s'enfonce dans le noir avec la salle.
	_dark = move_toward(_dark, 1.0 if r.get("dark", false) else 0.0, delta * 4.0)
	var tint := Color.WHITE.lerp(Color(0.42, 0.36, 0.38), _dark)
	if t - enemy.hurt_at < 0.12:
		tint = Color(1.6, 0.75, 0.7)
	scale = Vector2.ONE
	if dead:
		var k := clampf((t - enemy.died_at) / OeilMatrice.COLLAPSE, 0.0, 1.0)
		tint = Color(1.0 + 0.6 * (1.0 - k), 1.0 - 0.2 * k, 1.0 - 0.2 * k, 1.0 - k * k)
		scale = Vector2(1.0 + 0.06 * k, 1.0 - 0.45 * k)
		if k >= 1.0:
			visible = false
	modulate = tint


## Image f de l'atlas m ; row : rangée imposée (iris et paupières : une rangée par phase).
static func _cell(m: Dictionary, f: int, row := -1) -> Rect2:
	var cols := int(m["cols"])
	var w := float(m["frame_w"])
	var h := float(m["frame_h"])
	if row >= 0:
		return Rect2(f * w, row * h, w, h)
	return Rect2((f % cols) * w, (f / cols) * h, w, h)
