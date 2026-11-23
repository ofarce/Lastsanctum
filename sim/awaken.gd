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


static func tick(sim: Simulation) -> void:
	if GameState.ended or sim.world == null:
		return
	var st := sim.state()
	if st == null or not st.groves:
		return
	var now := GameState.sim_time
	var ops: TerrainOps = sim.world.terrain_ops
	for p: Dictionary in st.portals:
		if p["active"]:
			# Partie rechargée : pylône éveillé dont l'obélisque n'est pas encore au décor.
			if ops != null and not ops.dressed.has(p["id"]):
				ops.dress_pylon(p)
			continue
		if not seen(Vector2(float(p["x"]), float(p["z"]))):
			continue
		if ops != null:
			ops.wake_pylon(p)
		else:
			p["active"] = true
			p["next"] = now + 5.0
