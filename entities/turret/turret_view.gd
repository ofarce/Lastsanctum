class_name TurretView
extends Node2D
## Baliste de l'entrée (drawTurret, turret-game.js, 73b410f) : ruine animée tant que l'Ancre est éteinte,
## puis Garde tyrienne active dont l'arme suit sa cible sur 360° (turretYaw : rattrapage de 20 % de l'écart
## par image) et dont l'image suit le cycle de tir (phase = cycleAge / cycle).
## Images précalculées : ruine (boucle) ; arme active en 16 orientations × 24 phases.
## Origine : point au sol, sans arrondi (comme drawImage au pixel près dans le prototype).

const SW := 320
const SH := 240

static var _meta: Dictionary

var turret: Dictionary
var _ruin: Texture2D
var _weapon: Texture2D
## Orientation courante de l'arme (b.yaw), en radians dans le plan du monde.
var yaw := PI / 4.0


func setup(b: Dictionary) -> void:
	turret = b
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["buildings"]["ballista"]
	_ruin = load("res://assets/baked/buildings/ballista_ruin_anim.png")
	_weapon = load("res://assets/baked/buildings/ballista_weapon.png")
	position = Proj.nat(b["x"], 0.0, b["z"])


func _process(_delta: float) -> void:
	queue_redraw()


## turretYaw : l'arme se tourne vers sa cible (ou sa dernière visée) de 20 % de l'écart à chaque image.
func _turn() -> float:
	var b := turret
	var t: Variant = null
	if b["target"] != null and b["target"].hp > 0.0:
		t = b["target"]
	elif b["aim"] != null and b["aim"].hp > 0.0:
		t = b["aim"]
	if t != null:
		var want := atan2(t.z - b["z"], t.x - b["x"])
		yaw += atan2(sin(want - yaw), cos(want - yaw)) * 0.2
	return yaw


func _draw() -> void:
	var b := turret
	var src: Rect2
	var tex: Texture2D
	var anchor: Array
	if b["complete"]:
		var W: Dictionary = _meta["active"]["weapon"]
		var y := _turn()
		var yi := posmod(roundi(y / (TAU / float(W["yaws"]))), int(W["yaws"]))
		var pi := posmod(floori(b["cycle_age"] / Catalog.TURRET["cycle"] * float(W["phases"])), int(W["phases"]))
		src = Rect2(pi * SW, yi * SH, SW, SH)
		tex = _weapon
		anchor = _meta["active"]["anchor"]
	else:
		var A: Dictionary = _meta["ruin"]["anim"]
		var i := floori(GameState.sim_time * float(A["fps"])) % int(A["count"])
		src = Rect2((i % int(A["cols"])) * SW, (i / int(A["cols"])) * SH, SW, SH)
		tex = _ruin
		anchor = _meta["ruin"]["anchor"]
	draw_texture_rect_region(tex, Rect2(-float(anchor[0]), -float(anchor[1]), SW, SH), src)
