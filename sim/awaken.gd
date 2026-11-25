class_name Awaken
extends RefCounted
## Éveil à la vue (planches/galeries-reliees-propositions.html, P6 et P8, 2026-11-22). Les galeries sont toutes
## ouvertes dès le départ : ce qui s'éveillait à la découverte de sa galerie s'éveille désormais quand un allié
## passe à SIGHT unités ou moins (la vision de 5 cases plus une marge).
##
## - Pylône : obélisque, nappe et meute n'existent qu'une fois éveillé (TerrainOps.wake_pylon) ; il ne lâche pas
##   de meute la nuit avant (Night, p["active"]).
## - Tanière d'errants : son groupe apparaît à l'éveil (Roamers).

const SIGHT := 60.0


## Un allié vivant et visible est à `r` unités de `p` ou moins.
static func seen(p: Vector2, r := SIGHT) -> bool:
	var r2 := r * r
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and u.pos().distance_squared_to(p) <= r2:
			return true
	return false


## Instantané des alliés vivants et visibles, pour interroger beaucoup de points dans le même tick sans reparcourir
## toutes les unités (Roamers.tick : une tanière par salle et par galerie). Même réponse que seen() tant qu'aucune
## unité ne bouge, ne meurt ni ne se cache entre la prise et la question.
class Watch:
	extends RefCounted
	var pts := PackedVector2Array()
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF

	func seen(p: Vector2, r: float) -> bool:
		# Hors du cadre des alliés élargi de r (et d'une unité de marge d'arrondi) : aucun n'est à portée.
		var m := r + 1.0
		if p.x < x0 - m or p.x > x1 + m or p.y < z0 - m or p.y > z1 + m:
			return false
		var r2 := r * r
		for q in pts:
			if q.distance_squared_to(p) <= r2:
				return true
		return false


static func watch() -> Watch:
	var w := Watch.new()
	for u: Unit in GameState.units:
		if u.hp > 0.0 and not u.hidden:
			var q := Vector2(u.x, u.z)
			w.pts.append(q)
			w.x0 = minf(w.x0, q.x)
			w.x1 = maxf(w.x1, q.x)
			w.z0 = minf(w.z0, q.y)
			w.z1 = maxf(w.z1, q.y)
	return w


static func tick(sim: Simulation) -> void:
	if GameState.ended or sim.world == null:
		return
	var st := sim.state()
	if st == null or not st.groves:
		return
	var now := GameState.sim_time
	var ops: TerrainOps = sim.world.terrain_ops
	var w: Watch = null
	for p: Dictionary in st.portals:
		if p["active"]:
			# Partie rechargée : pylône éveillé dont l'obélisque n'est pas encore au décor.
			if ops != null and not ops.dressed.has(p["id"]):
				ops.dress_pylon(p)
			continue
		if w == null:
			w = watch()
		if not w.seen(Vector2(float(p["x"]), float(p["z"])), SIGHT):
			continue
		if ops != null:
			ops.wake_pylon(p)
		else:
			p["active"] = true
			p["next"] = now + 5.0
