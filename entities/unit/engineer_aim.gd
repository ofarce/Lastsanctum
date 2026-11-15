class_name EngineerAim
extends RefCounted
## Pose de tir de l'Ingénieur quand il creuse avec le lance-pitons (planche « Pitons d'ancrage —
## Suspension ») : le bras vise l'angle de la case où part le prochain piton, recule au tir, puis se tourne
## vers l'angle suivant ; pendant la suspension, il vise le centre de la case, générateur à pleine lueur.
## Images : res://assets/imported/engineer/engineer_aim.png (angles de −90° à +90° par pas de 10°, lignes :
## recul 0 / 1,5 / 3, puis suspension), générées depuis EngineerKit (même gabarit que le repos).

const SHEET := "res://assets/imported/engineer/engineer_aim.png"
const META := "res://assets/imported/engineer/engineer_aim.json"
## Sans armure (surcharge de l'Ancre) : lance-pitons noué sur l'avant-bras nu, même géométrie (épaule,
## bouche, ancre) que la planche armée ; générée par planches/ingenieur-sans-armure-export.html.
const SHEET_BARE := "res://assets/imported/engineer/engineer_bare_aim.png"
## Recul après un tir et rotation vers l'angle suivant (secondes).
const RECOIL := 0.12
const TURN := 0.1
## Fin de la pose de suspension : les pitons reviennent au poignet (q = 0,85 de la suspension).
const SUSPEND_END := 0.85

static var meta: Dictionary
static var frames: Array = []
static var frames_bare: Array = []


static func load_frames() -> void:
	if not frames.is_empty():
		return
	meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	frames = _sheet(load(SHEET))
	frames_bare = _sheet(load(SHEET_BARE))


static func _sheet(tex: Texture2D) -> Array:
	var out: Array = []
	for r in int(meta["rows"]):
		var row: Array[AtlasTexture] = []
		for c in int(meta["cols"]):
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(c * float(meta["frame_w"]), r * float(meta["frame_h"]), meta["frame_w"], meta["frame_h"])
			row.append(a)
		out.append(row)
	return out


## Épaule avant par rapport au point au sol, en pixels natifs, Ingénieur tourné vers la droite.
static func shoulder() -> Vector2:
	return Vector2(float(meta["shoulder"][0]) - float(meta["ax"]), float(meta["shoulder"][1]) - float(meta["ay"]))


## Angle de visée (degrés, −90 haut, +90 bas, Ingénieur tourné vers `face`) de (x, z) vers la cible.
static func angle_to(x: float, z: float, target: Vector2, face: int) -> float:
	load_frames()
	var d := Proj.nat(target.x, 0.0, target.y) - Proj.nat(x, 0.0, z) - Vector2(shoulder().x * face, shoulder().y)
	return clampf(rad_to_deg(atan2(d.y, maxf(0.5, d.x * face))), -90.0, 90.0)


static func face_to(x: float, target: Vector2, fallback: int) -> int:
	var dx := target.x - x
	return fallback if absf(dx) < 0.05 else (-1 if dx < 0.0 else 1)


static func bin(angle: float) -> int:
	return clampi(roundi((angle + 90.0) / 10.0), 0, int(meta["cols"]) - 1)


## Bouche du lance-pitons par rapport au point au sol (pixels natifs) pour un angle et une orientation.
static func muzzle(angle: float, face: int) -> Vector2:
	load_frames()
	var m: Array = meta["muzzle"][bin(angle)]
	return Vector2((float(m[0]) - float(meta["ax"])) * face, float(m[1]) - float(meta["ay"]))


## Suspension en cours lancée par cet Ingénieur (effet « suspend »), ou null.
static func suspension(u: Unit) -> Variant:
	for e in GameState.effects:
		if e["type"] == "suspend" and e["unit"] == u and e["age"] / e["duration"] < SUSPEND_END:
			return e
	return null


## Pose courante : {frame: AtlasTexture, face: int, ax, ay} ou null si l'Ingénieur ne tire pas.
static func pose(u: Unit, st: TerrainState) -> Variant:
	if u.role != "engineer" or st == null:
		return null
	load_frames()
	var now := GameState.sim_time
	var target: Vector2
	var row := 0
	var angle := 0.0
	var face := u.face if u.face != 0 else 1
	# La suspension ne prend la pose que si l'Ingénieur n'enchaîne pas déjà sur une autre case.
	var digging: bool = u.working and u.job != null and u.job["type"] == "dig"
	var sus: Variant = null if digging else suspension(u)
	if sus != null:
		target = Vector2(sus["x"], sus["z"])
		face = face_to(u.x, target, face)
		angle = angle_to(u.x, u.z, target, face)
		row = 3
	else:
		var j: Variant = u.job
		if not digging:
			return null
		var key := Vector2i(j["cell"]["i"], j["cell"]["j"])
		var h: int = st.dig_hits.get(key, 0)
		var since: float = now - float(st.dig_hit_at.get(key, -100.0))
		var nxt := Combat.piton_corner(key, mini(h, 3))
		if h > 0 and since < RECOIL:
			target = Combat.piton_corner(key, h - 1)
			face = face_to(u.x, target, face)
			angle = angle_to(u.x, u.z, target, face)
			var rc := 3.0 * sin(PI * since / RECOIL)
			row = 0 if rc < 0.75 else (1 if rc < 2.25 else 2)
		else:
			face = face_to(u.x, nxt, face)
			angle = angle_to(u.x, u.z, nxt, face)
			if h > 0:
				var prev := angle_to(u.x, u.z, Combat.piton_corner(key, h - 1), face)
				var e := clampf((since - RECOIL) / TURN, 0.0, 1.0)
				angle = lerpf(prev, angle, 0.5 - 0.5 * cos(PI * e))
	u.face = face
	return {"frame": (frames_bare if u.unarmored else frames)[row][bin(angle)], "face": face, "ax": float(meta["ax"]), "ay": float(meta["ay"])}
