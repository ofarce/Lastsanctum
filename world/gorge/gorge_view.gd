class_name GorgeView
extends Node2D
## Rendu de la Gorge-Cuivre (sim/gorge.gd) : un atlas par état du combat (assets/imported/gorge, exportés par
## tools/biomes-persos/export_gorge.py), dessiné à sa taille native (cadre 104 × 88, quatre fois la surface d’un soldat) ;
## les annonces au sol (cercle de la Percée, points de chute de la Pluie, ligne du sillon) et les blocs qui tombent,
## dessinés à part par GorgeMarks (draw_marks). Origine : le point au sol du boss, dans le tri en profondeur du monde.

const DIR := "res://assets/imported/gorge/"
const SCALE := 1.0
const WARN := Color("#f0b088")
const ROCK := [Color("#2a120a"), Color("#7a4530"), Color("#c47b58"), Color("#f0b088")]

static var _meta: Dictionary
static var _tex := {}

var enemy: Enemy
var world: World


static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "meta.json"))
		for name: String in _meta["anims"]:
			_tex[name] = load(DIR + name + ".png")
	return _meta


func setup(e: Enemy, w: World) -> void:
	enemy = e
	world = w
	name = "GorgeCuivre"
	meta()


func _process(_delta: float) -> void:
	if enemy == null:
		return
	position = Proj.nat(enemy.x, 0.0, enemy.z).round()
	queue_redraw()


## Animation et avancement (0 → 1, ou temps pour une boucle) selon l'état du combat.
func _pose() -> Array:
	var r := Gorge.run()
	var now := GameState.sim_time
	if enemy.hp <= 0.0:
		return ["death", now - enemy.died_at, false]
	var mode := String(r.get("mode", "sleep"))
	var k := clampf((now - float(r.get("t0", now))) / maxf(0.01, float(r.get("until", now)) - float(r.get("t0", now))), 0.0, 1.0)
	match mode:
		"sleep", "travel", "warn", "furrow_warn", "furrow_run":
			return ["mound", now, true]
		"sink", "sink_sleep", "furrow_sink":
			return ["sink", k, false]
		"emerge", "emerge_open":
			return ["emerge", k, false]
		"rear":
			return ["rear", k, false]
		"open", "rain":
			return ["rear", 1.0, false]
	# Phase III : elle reste cabrée, gueule ouverte.
	return ["rear", 1.0, false] if int(r.get("phase", 0)) == 2 else ["idle", now, true]


func _draw() -> void:
	if enemy == null:
		return
	var m := meta()
	var now := GameState.sim_time
	var seen := world == null or world.fog.visible_at(enemy.pos())
	if not seen:
		return
	var pose := _pose()
	var a: Dictionary = m["anims"][pose[0]]
	var n := int(a["count"])
	var f := floori(float(pose[1]) * float(a["fps"])) % n if pose[2] else clampi(floori(float(pose[1]) * (n - 1) + 0.5), 0, n - 1)
	if pose[0] == "death":
		f = clampi(floori(float(pose[1]) * float(a["fps"])), 0, n - 1)
	var fw := float(m["frame_w"])
	var fh := float(m["frame_h"])
	var cols := int(m["cols"])
	var src := Rect2((f % cols) * fw, (f / cols) * fh, fw, fh)
	var face := -1.0 if enemy.face < 0 else 1.0
	var tint := Color.WHITE
	if now - enemy.hurt_at < 0.12 and enemy.hp > 0.0:
		tint = Color(1.7, 1.5, 1.3)
	elif Gorge.mouth_open() and enemy.hp > 0.0 and int(now * 6.0) % 2 == 0:
		tint = Color(1.15, 1.05, 1.0)
	if enemy.hp <= 0.0:
		tint = Color(1, 1, 1, clampf(Loot.corpse_life(enemy) - (now - enemy.died_at), 0.0, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE * face, SCALE))
	draw_texture_rect_region(_tex[pose[0]], Rect2(-float(a["ax"]), -float(m["ay"]), fw, fh), src, tint)
	draw_set_transform(Vector2.ZERO)


## Annonces au sol : cercles pointillés qui se remplissent, ligne du sillon, blocs en chute. Dessinées par GorgeMarks,
## au-dessus des sprites (bilan « Visibilité des balles », 2026-11-20 : un arbre ne les cache plus), en pixels natifs.
static func draw_marks(ci: CanvasItem, w: World, r: Dictionary, now: float) -> void:
	for m: Dictionary in r.get("marks", []):
		var at := Vector2(m["x"], m["z"])
		if w != null and not w.fog.visible_at(at):
			continue
		var k := clampf((now - float(m["from"])) / maxf(0.01, float(m["at"]) - float(m["from"])), 0.0, 1.0)
		var rr := float(m["r"])
		for i in 40:
			if (i + int(now * 8.0)) % 2 == 0:
				continue
			var a := TAU * i / 40.0
			var p := _nat(at.x + cos(a) * rr, at.y + sin(a) * rr).round()
			ci.draw_rect(Rect2(p, Vector2.ONE), Color(WARN, 0.9))
		for i in 24:
			var a := TAU * i / 24.0
			var p := _nat(at.x + cos(a) * rr * k, at.y + sin(a) * rr * k).round()
			ci.draw_rect(Rect2(p, Vector2.ONE), Color(WARN, 0.55))
		if m["kind"] == "rain":
			# Bloc de minerai : tombe de 90 px natifs, son ombre grossit.
			var c := _nat(at.x, at.y).round()
			var h := roundf((1.0 - k * k) * 90.0)
			ci.draw_rect(Rect2(c + Vector2(-2 - 2 * k, -1), Vector2(4 + 4 * k, 2)), Color(0, 0, 0, 0.35))
			ci.draw_rect(Rect2(c + Vector2(-4, -h - 7), Vector2(8, 8)), ROCK[0])
			ci.draw_rect(Rect2(c + Vector2(-3, -h - 6), Vector2(6, 6)), ROCK[1])
			ci.draw_rect(Rect2(c + Vector2(-3, -h - 6), Vector2(4, 3)), ROCK[2])
			ci.draw_rect(Rect2(c + Vector2(-2, -h - 5), Vector2(2, 1)), ROCK[3])
	if r.has("furrow"):
		var fu: Dictionary = r["furrow"]
		var a: Vector2 = fu["a"]
		var b: Vector2 = fu["b"]
		var n := maxi(2, int(a.distance_to(b)))
		var side := (b - a).normalized().orthogonal() * float(Gorge.FURROW["width"])
		for i in n:
			if (i + int(now * 10.0)) % 2 == 0:
				continue
			var q := a.lerp(b, float(i) / n)
			for s: float in [-1.0, 1.0]:
				var p := _nat(q.x + side.x * s, q.y + side.y * s).round()
				ci.draw_rect(Rect2(p, Vector2.ONE), Color(WARN, 0.9))


static func _nat(x: float, z: float) -> Vector2:
	return Proj.nat(x, 0.0, z)
