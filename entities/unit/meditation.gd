class_name Meditation
extends RefCounted
## Méditation en lévitation de l'Ingénieur (planche ingenieur-priere-propositions.html, proposition 5) :
## il s'assoit en tailleur (planche « settle »), décolle de quelques pixels et flotte (planche « lotus »).
## Trois lueurs du culte gravitent autour de lui ; à chaque gain (+5 par seconde entière après l'assise),
## l'une quitte l'orbite et file au temple, qui s'éclaire ; un halo en paliers tramés bat sous lui.
## Les effets sont en pixels natifs tramés (Bayer 4×4), relatifs aux pieds de l'Ingénieur.

const SETTLE := Simulation.MEDITATE_SETTLE
## Lueur détachée de l'orbite : part 0,3 s avant le gain, arrive au temple à l'instant du gain.
const FLIGHT := 0.3
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


## État de la méditation, ou {} si l'unité ne médite pas : age (depuis l'arrivée), b0 (fin de l'assise),
## temple, ramp (couleurs du culte).
static func state(u: Unit) -> Dictionary:
	if u.role != "engineer" or not u.working or u.job == null or u.job.get("type") != "pray" or not u.job.has("since"):
		return {}
	var t: Building = u.job["temple"]
	var since: float = u.job["since"]
	return {"age": GameState.sim_time - since, "b0": since + SETTLE, "temple": t, "ramp": Catalog.DEITY_RAMP[t.def()["deity"]]}


## Lévitation (pixels natifs) : monte en 0,7 s après l'assise, puis oscille.
static func lift(age: float) -> float:
	var w := age - SETTLE
	if w <= 0.0:
		return 0.0
	return smoothstep(0.0, 1.0, w / 0.7) * (5.0 + sin(w * 2.4) * 1.4) * 0.5


## Cœur du temple (pixels natifs), point d'arrivée des lueurs.
static func heart(t: Building) -> Vector2:
	return Proj.nat(t.x, 2.0, t.z + t.half() * 0.5)


## Position d'une lueur en orbite (relative aux pieds) et son côté (devant / derrière l'Ingénieur).
static func orb(j: int, time: float, lifted: float, face: int) -> Dictionary:
	var a := time * 1.8 + j * TAU / 3.0
	var c := Vector2(1.5 * face, -11.5 - lifted + 2.0)
	return {"p": c + Vector2(cos(a) * 11.0, sin(a) * 3.5), "front": sin(a) > 0.0}


## Opacité de la lueur j : absente pendant l'assise, éteinte quand elle part au temple, puis renaît.
static func orb_alpha(j: int, time: float, b0: float) -> float:
	var v := clampf((time - b0 - 0.3) / 0.4, 0.0, 1.0)
	var k0 := floori(time - b0)
	for k in range(maxi(1, k0 - 1), k0 + 2):
		if k % 3 != j:
			continue
		var t0 := b0 + k - FLIGHT
		if time >= t0 and time < t0 + 0.55:
			return 0.0
		if time >= t0 + 0.55 and time < t0 + 0.95:
			v = minf(v, (time - t0 - 0.55) / 0.4)
	return v


## Pulsation du halo au sol : 1 à l'instant d'un gain, retombe en 0,6 s.
static func pulse(time: float, b0: float) -> float:
	var a := time - b0
	if a < 1.0:
		return 0.0
	return maxf(0.0, 1.0 - fmod(a, 1.0) / 0.6)


# ---------------------------------------------------------------- Pixels tramés

static func _bay(x: int, y: int) -> float:
	return (BAYER[y & 3][x & 3] + 0.5) / 16.0


static func dpx(ci: CanvasItem, x: float, y: float, c: Color, a := 1.0) -> void:
	var xi := roundi(x)
	var yi := roundi(y)
	if a <= 0.0 or (a < 1.0 and a <= _bay(xi, yi)):
		return
	ci.draw_rect(Rect2(xi, yi, 1, 1), c)


static func disc(ci: CanvasItem, cx: float, cy: float, r: float, c: Color, a := 1.0) -> void:
	for y in range(floori(cy - r), ceili(cy + r) + 1):
		for x in range(floori(cx - r), ceili(cx + r) + 1):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length() / r
			if d <= 1.0:
				dpx(ci, x, y, c, a * (1.0 - d * d * 0.6))


## Halo en paliers : trois anneaux de densité décroissante.
static func halo(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float, L: Array, a := 1.0) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry).length()
			if d > 1.0:
				continue
			var tier := 0.75 if d < 0.35 else (0.45 if d < 0.7 else 0.2)
			dpx(ci, x, y, L[3] if d < 0.35 else L[2], a * tier)


static func ring(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float, c: Color, a := 1.0) -> void:
	var n := maxi(10, ceili(rx * 7.0))
	for k in n:
		var t := TAU * k / n
		dpx(ci, cx + cos(t) * rx, cy + sin(t) * ry, c, a)


static func mote(ci: CanvasItem, p: Vector2, L: Array, a := 1.0, r := 1.2) -> void:
	r += 0.6
	disc(ci, p.x, p.y, r + 3.0, L[2], 0.4 * a)
	disc(ci, p.x, p.y, r + 1.2, L[3], 0.75 * a)
	disc(ci, p.x, p.y, r, L[4], a)
	dpx(ci, p.x, p.y, L[5], a)
	dpx(ci, p.x + 1, p.y, L[5], a)
	dpx(ci, p.x, p.y + 1, L[5], a * 0.8)


static func bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + b * t * t


# ---------------------------------------------------------------- Calques

## Sous l'Ingénieur : halo au sol et lueurs passant derrière lui.
static func draw_back(ci: CanvasItem, u: Unit, face: int) -> void:
	var S := state(u)
	if S.is_empty():
		return
	var time := GameState.sim_time
	var b0: float = S["b0"]
	var L: Array = S["ramp"]
	var on := clampf((time - b0) / 0.5, 0.0, 1.0)
	if on > 0.0:
		var p := pulse(time, b0)
		halo(ci, 1.0, 0.0, 10.0 + p * 4.0, 3.4 + p * 1.2, L, on * (0.45 + 0.4 * p))
	var lifted := lift(S["age"])
	for j in 3:
		var o := orb(j, time, lifted, face)
		if not o["front"]:
			mote(ci, o["p"], L, orb_alpha(j, time, b0), 1.1)


## Devant l'Ingénieur : lueurs en orbite, lueur en vol vers le temple, éclat du temple au gain.
static func draw_front(ci: CanvasItem, u: Unit, face: int, origin: Vector2) -> void:
	var S := state(u)
	if S.is_empty():
		return
	var time := GameState.sim_time
	var b0: float = S["b0"]
	var L: Array = S["ramp"]
	var lifted := lift(S["age"])
	for j in 3:
		var o := orb(j, time, lifted, face)
		if o["front"]:
			mote(ci, o["p"], L, orb_alpha(j, time, b0), 1.2)
	var H := heart(S["temple"]) - origin
	var k := floori(time - b0) + 1
	var t0 := b0 + k - FLIGHT
	if k >= 1 and time >= t0:
		var start: Vector2 = orb(k % 3, t0, lift(t0 - b0 + SETTLE), face)["p"]
		var c := Vector2(lerpf(start.x, H.x, 0.5), minf(start.y, H.y) - 12.0)
		var q := (time - t0) / FLIGHT
		var s := pow(q, 3.0) * 0.7 + q * 0.3
		for i in range(10, 0, -1):
			var tp := bez(start, c, H, maxf(0.0, s - i * 0.04))
			var kk := 1.0 - i / 11.0
			dpx(ci, tp.x, tp.y, L[4] if i < 4 else L[3], kk)
			if i < 6:
				dpx(ci, tp.x + 1, tp.y, L[3], kk * 0.8)
		mote(ci, bez(start, c, H, s), L, 1.0, 1.5)
	# Éclat du temple : à chaque gain, pendant 0,5 s.
	var age := time - b0 - floorf(time - b0)
	if time - b0 >= 1.0 and age < 0.5:
		var e := age / 0.5
		var g := 1.0 - pow(1.0 - e, 3.0)
		halo(ci, H.x, H.y, 4.0 + g * 9.0, 4.0 + g * 9.0, L, 1.0 - e)
		ring(ci, H.x, H.y, 3.0 + g * 14.0, (3.0 + g * 14.0) * 0.7, L[4], (1.0 - e) * 0.8)
