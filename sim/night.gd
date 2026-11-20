class_name Night
extends RefCounted
## La nuit n'est plus calme (demande du 2026-11-20). Deux pressions, après le premier assaut seulement :
##
## - Flot nocturne : des squelettes épars se lèvent un peu partout sur le no man's land (dehors, au sud du
##   flanc de la montagne ; jamais dans la grotte ni les galeries), du crépuscule à la fin de nuit. Rares au début, plus serrés au cœur de la nuit, plus aucun avant l'aube
##   (Catalog.NIGHT_FLOW). Chaque palier de menace resserre le flot et renforce les squelettes.
## - Meutes des pylônes : chaque nuit, tout Pylône de Merenor éveillé (galerie découverte) et non canalisé lâche
##   une meute de chiens qui marche sur l'Ancre (Catalog.NIGHT_RAID), d'autant plus nombreuse et forte que la
##   menace est haute. Les gardiens du pylône, eux, restent en laisse (sim/pylons.gd). Toute la carte étant
##   reliée (32 pylônes), les pylônes endormis ne lâchent rien, sauf le plus proche de l'Ancre parmi les non
##   canalisés : il y a donc toujours au moins une meute, et la faire taire demande d'aller le canaliser.
##
## Squelettes et meutes sont hors menace et hors fin de vague (Enemy.beast) : ils ne rapportent pas de menace
## et ne retardent pas l'assaut du matin.

## Essais de tirage d'une place libre dehors avant de renoncer pour ce coup-ci.
const TRIES := 12


static func tick(sim: Simulation, _dt: float) -> void:
	if GameState.ended or not GameState.orb_active or GameState.wave < 1:
		return
	var now := GameState.sim_time
	var f := DayNight.fraction(now)
	_flow(sim, now, f)
	if f >= float(Catalog.NIGHT_RAID["at"]):
		_raids(sim, DayNight.day(now))


# ---------------------------------------------------------------- Flot de squelettes

## Intervalle entre deux squelettes à la fraction de journée f (INF hors du flot).
static func gap(f: float, tier: int) -> float:
	var F: Dictionary = Catalog.NIGHT_FLOW
	if f < float(F["from"]) or f > float(F["to"]):
		return INF
	var u := (f - float(F["from"])) / (float(F["to"]) - float(F["from"]))
	var g := lerpf(float(F["early"]), float(F["peak"]), sin(u * PI))
	return maxf(float(F["min_gap"]), g / (1.0 + float(F["rate"]) * tier))


static func _flow(sim: Simulation, now: float, f: float) -> void:
	var tier := Catalog.menace_tier(GameState.menace)
	var g := gap(f, tier)
	if is_inf(g):
		GameState.night_next = 0.0
		return
	if GameState.night_next == 0.0:
		GameState.night_next = now + g * sim.rng.randf()
		var day := DayNight.day(now)
		if GameState.night_day != day:
			GameState.night_day = day
			Events.wave_alert.emit("La nuit tombe : des squelettes se lèvent dans le no man’s land.", 4.0)
		return
	if now < GameState.night_next:
		return
	GameState.night_next = now + g * (0.6 + 0.8 * sim.rng.randf())
	var at: Variant = spot(sim)
	if at == null:
		return
	var e := Enemy.make("skeleton", at.x, at.y, 0.3 + sim.rng.randf() * 0.7, Catalog.menace_stats(tier))
	e.beast = true
	# Il sort de terre en silhouette noire, puis prend ses couleurs (UnitView).
	e.risen_at = now
	GameState.enemies.append(e)


## Place où un squelette se lève : dehors, praticable, loin du flanc de la montagne et des alliés ; null si
## aucun tirage ne convient.
static func spot(sim: Simulation) -> Variant:
	var F: Dictionary = Catalog.NIGHT_FLOW
	var st := sim.state()
	var z1 := CaveShape.WORLD_Z1 - 6.0
	for _i in TRIES:
		var x := (sim.rng.randf() * 2.0 - 1.0) * float(F["x"])
		var z0 := CaveShape.mountain_edge(x) + float(F["flank"])
		var z := lerpf(z0, z1, sim.rng.randf())
		if not CaveShape.outdoors(x, z) or not st.walkable(x, z):
			continue
		var p := Vector2(x, z)
		var clear := float(F["clear"])
		if GameState.units.any(func(u: Unit) -> bool: return u.alive() and not u.hidden and u.pos().distance_to(p) < clear):
			continue
		return p
	return null


# ---------------------------------------------------------------- Meutes des pylônes

## Effectif de la meute nocturne d'un pylône au palier de menace donné.
static func raid_size(tier: int) -> int:
	var R: Dictionary = Catalog.NIGHT_RAID
	return mini(int(R["cap"]), int(R["base"]) + int(R["per_tier"]) * tier)


## Pylône non canalisé le plus proche de l'Ancre ({} s'il n'en reste aucun).
static func nearest_open(st: TerrainState) -> Dictionary:
	var best := {}
	var best_d := INF
	for p: Dictionary in st.portals:
		if bool(p.get("channeled", false)):
			continue
		var d := CaveShape.CORE.distance_squared_to(Vector2(float(p["x"]), float(p["z"])))
		if d < best_d:
			best_d = d
			best = p
	return best


static func _raids(sim: Simulation, day: int) -> void:
	if sim.world == null:
		return
	var st := sim.state()
	var packs := 0
	var near := nearest_open(st)
	for p: Dictionary in st.portals:
		if int(p.get("raid_day", 0)) == day:
			continue
		p["raid_day"] = day
		if bool(p.get("channeled", false)) or not (bool(p["active"]) or is_same(p, near)):
			continue
		# Au sud du socle (infranchissable) ; sans chemin jusqu'à l'Ancre (galerie encore scellée), pas de meute.
		var from := st.push_out_of_rock(Vector2(float(p["x"]), float(p["z"]) + 6.5))
		if sim.world.pathfinder.find_path(from, CaveShape.CORE) == null:
			continue
		var tier := Catalog.menace_tier(GameState.menace) + Biomes.threat_tiers(int(p.get("threat", 1)))
		var stats := Catalog.menace_stats(tier, true)
		var n := raid_size(Catalog.menace_tier(GameState.menace))
		for k in n:
			var at := from + Vector2.from_angle(float(k) / n * TAU) * 2.4
			if not st.walkable(at.x, at.y):
				at = from
			var e := Enemy.make("beast", at.x, at.y, 0.6 + 0.1 * k, stats)
			e.raid = true
			GameState.enemies.append(e)
		Sfx.at("aberration", from.x, from.y)
		packs += 1
	if packs > 0:
		Events.wave_alert.emit("%d meute%s de Merenor quitte%s %s et marche%s sur l’Ancre !" % [packs,
			"s" if packs > 1 else "", "nt" if packs > 1 else "", "leurs pylônes" if packs > 1 else "son pylône",
			"nt" if packs > 1 else ""], 5.0)
