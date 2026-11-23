class_name ArchipretreView
extends Node2D
## Rendu de l'Archiprêtre aux racines (sim/archipretre.gd) : une bande par animation (assets/imported/archipretre,
## exportées par tools/archipretre/export.py), cadre 56 × 56 à sa taille native, pied au milieu du bas. Repos (bulbe
## qui pulse), point faible (bulbe ouvert, quatre cultes en prière), appel des racines, chute. Lueur du bulbe par
## dessus. Origine : le point au sol du boss, dans le tri en profondeur du monde.

const DIR := "res://assets/imported/archipretre/"
## Position du bulbe dans le cadre (px natifs, depuis le pied).
const BULB := Vector2(0.0, -44.0)

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
	name = "Archipretre"
	meta()


func _process(_delta: float) -> void:
	if enemy == null:
		return
	position = Proj.nat(enemy.x, 0.0, enemy.z).round()
	queue_redraw()


## Animation et avancement selon l'état du combat : [nom, temps ou avancement, boucle].
func _pose() -> Array:
	var r := Archipretre.run()
	var now := GameState.sim_time
	if enemy.hp <= 0.0:
		return ["death", now - enemy.died_at, false]
	if Archipretre.bulb_open():
		return ["open", now, true]
	if String(r.get("mode", "")) == "cast":
		var k := clampf((now - float(r.get("t0", now))) / maxf(0.01, float(r.get("until", now)) - float(r.get("t0", now))), 0.0, 1.0)
		return ["cast", k, false]
	return ["idle", now, true]


func _draw() -> void:
	if enemy == null or enemy.hidden:
		return
	if world != null and not world.fog.visible_at(enemy.pos()):
		return
	var m := meta()
	var now := GameState.sim_time
	var pose := _pose()
	var a: Dictionary = m["anims"][pose[0]]
	var n := int(a["count"])
	var f := 0
	if pose[0] == "death":
		f = clampi(floori(float(pose[1]) * float(a["fps"])), 0, n - 1)
	elif pose[2]:
		f = floori(float(pose[1]) * float(a["fps"])) % n
	else:
		f = clampi(floori(float(pose[1]) * (n - 1) + 0.5), 0, n - 1)
	var fw := float(m["frame_w"])
	var fh := float(m["frame_h"])
	var tint := Color.WHITE
	if now - enemy.hurt_at < 0.12 and enemy.hp > 0.0:
		tint = Color(1.7, 1.5, 1.3)
	if enemy.hp <= 0.0:
		tint = Color(1, 1, 1, clampf(Loot.corpse_life(enemy) - (now - enemy.died_at), 0.0, 1.0))
	var face := -1.0 if enemy.face < 0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1.0))
	draw_texture_rect_region(_tex[pose[0]], Rect2(-float(m["ax"]), -float(m["ay"]), fw, fh), Rect2(f * fw, 0.0, fw, fh), tint)
	draw_set_transform(Vector2.ZERO)
	# Lueur du bulbe : sourde au repos, vive ouvert.
	if enemy.hp > 0.0:
		var open := Archipretre.bulb_open()
		var pulse := 0.5 + 0.5 * sin(now * (6.0 if open else 2.2))
		var c := Color(1.0, 0.85, 0.45, 0.10 + 0.10 * pulse) if open else Color(0.82, 0.25, 0.3, 0.05 + 0.05 * pulse)
		for k in 3:
			draw_circle(BULB, 6.0 + k * 4.0, Color(c, c.a * (1.0 - k * 0.3)))
