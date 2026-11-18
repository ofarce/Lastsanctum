class_name Road
extends RefCounted
## Chemins de la jungle (fonction de la graine) : la route principale descend de l'entrée de la caverne
## jusqu'au bord sud en quelques virages doux et franchit la rivière par le pont central ; deux chemins
## secondaires s'en détachent sur la rive nord vers le pont le plus proche de chaque côté (croisements).
## Décor seulement : la praticabilité n'en dépend pas.

const MAIN_HALF := 4.0
const BRANCH_HALF := 2.3
## Route droite devant l'entrée (tranchées des balistes) et de part et d'autre du pont.
const GATE_Z := -64.0
const BRIDGE_STRAIGHT := 9.0

var seed := 0
var river: River
var _p: Array[float] = []
var _a1 := 0.0
var _a2 := 0.0
var bridge_z := 0.0
## Croisements : {x, z, side, bx (pont visé)}.
var junctions: Array[Dictionary] = []


func _init(map_seed: int, r: River) -> void:
	seed = map_seed
	river = r
	var rng := Rng.new(map_seed ^ 0x40ad)
	for k in 4:
		_p.append(rng.next() * TAU)
	_a1 = (10.0 + rng.next() * 6.0) * (1.0 if rng.next() < 0.5 else -1.0)
	_a2 = (6.0 + rng.next() * 4.0) * (1.0 if rng.next() < 0.5 else -1.0)
	bridge_z = r.center(0.0) if r else 34.0
	if r == null:
		return
	# Un croisement par côté, sur la rive nord, vers le pont le plus proche.
	for side: float in [-1.0, 1.0]:
		var best: Dictionary = {}
		for b in r.bridges:
			var bx: float = b["x"]
			if bx * side > 20.0 and (best.is_empty() or absf(bx) < absf(float(best["x"]))):
				best = b
		if best.is_empty():
			continue
		var jz := bridge_z - 16.0 - rng.next() * 6.0
		junctions.append({"x": main_x(jz), "z": jz, "side": side, "bx": float(best["x"]), "b": best,
			"phase": rng.next() * TAU})


## Abscisse de la route principale à la profondeur z.
func main_x(z: float) -> float:
	var top := GATE_Z
	var b0 := bridge_z - BRIDGE_STRAIGHT
	var b1 := bridge_z + BRIDGE_STRAIGHT
	if z <= top or (z >= b0 and z <= b1):
		return 0.0
	if z < b0:
		var t := (z - top) / (b0 - top)
		return _a1 * sin(t * PI) * (0.85 + 0.15 * sin(t * 7.0 + _p[0]))
	var t := clampf((z - b1) / (CaveShape.WORLD_Z1 + 6.0 - b1), 0.0, 1.0)
	return _a2 * sin(t * PI * 1.4) * smoothstep(0.0, 0.25, t)


## Profondeur du chemin secondaire j à l'abscisse x (entre le croisement et son pont).
func branch_z(j: Dictionary, x: float) -> float:
	var span: float = float(j["bx"]) - float(j["x"])
	var t := clampf((x - float(j["x"])) / span, 0.0, 1.0)
	return float(j["z"]) + 3.0 * sin(t * PI * 2.0 + float(j["phase"])) * sin(t * PI)


## Distance signée au bord du chemin le plus proche (négative sur le chemin) et largeur relative :
## Vector3(distance, décalage latéral normalisé −1…1, abscisse curviligne). Distance INF loin de tout.
func sample(x: float, z: float) -> Vector3:
	var best := Vector3(INF, 0.0, 0.0)
	if z >= GATE_Z - 20.0:
		var mx := main_x(z)
		var d := absf(x - mx) - MAIN_HALF
		if d < best.x:
			best = Vector3(d, (x - mx) / MAIN_HALF, z)
	for j in junctions:
		var x0: float = j["x"]
		var bx: float = j["bx"]
		var lo := minf(x0, bx)
		var hi := maxf(x0, bx)
		if x >= lo - BRANCH_HALF and x <= hi + BRANCH_HALF:
			var bz := branch_z(j, clampf(x, lo, hi))
			var d := absf(z - bz) - BRANCH_HALF
			if x < lo or x > hi:
				d = maxf(d, maxf(lo - x, x - hi) - BRANCH_HALF)
			if d < best.x:
				best = Vector3(d, (z - bz) / BRANCH_HALF, x)
		# Descente vers le pont, puis un bout de chemin sur l'autre rive.
		var b: Dictionary = j["b"]
		var z_top := branch_z(j, bx)
		var z_bot := float(b["z1"]) + 9.0
		if z >= z_top and z <= z_bot and not river.on_deck(x, z):
			var d := absf(x - bx) - BRANCH_HALF
			if d < best.x:
				best = Vector3(d, (x - bx) / BRANCH_HALF, z)
	return best


func on_road(x: float, z: float, margin := 0.0) -> bool:
	return sample(x, z).x < margin


## Rectangles (unités) qui contiennent tous les chemins, pour la peinture du sol.
func bounds() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(-MAIN_HALF - 20.0, GATE_Z - 2.0, 2.0 * (MAIN_HALF + 20.0), CaveShape.WORLD_Z1 - GATE_Z + 8.0)]
	for j in junctions:
		var lo := minf(float(j["x"]), float(j["bx"])) - 4.0
		var hi := maxf(float(j["x"]), float(j["bx"])) + 4.0
		out.append(Rect2(lo, float(j["z"]) - 8.0, hi - lo, float((j["b"] as Dictionary)["z1"]) + 12.0 - float(j["z"]) + 8.0))
	return out
