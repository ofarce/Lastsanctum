class_name Mages
extends RefCounted
## Mages cristallisés de l'École de magie cristallisée (idée de l'utilisateur, 2026-11-20 ; chiffres de départ de
## planches/biomes-1-2-elements.html dans Catalog.MAGE). Ils ne frappent pas : ils suivent les ordres de
## déplacement, reculent quand un ennemi arrive au contact, et agissent seuls.
##  - Guérisseuse : soigne en continu l'allié le plus blessé à portée.
##  - Chantre : aura, les alliés dans son rayon frappent plus fort (deux auras ne se cumulent pas).
##  - Envoûteur : marque l'ennemi visible le plus proche et ses voisins, leur armure baisse quelques secondes.
## Rendu : AdeptView (rôles du manifeste), animation « work » pendant l'action ; aura et marques dans EffectsDrawer.

## Un ennemi à moins de FLEE unités fait reculer le mage de BACK unités.
const FLEE := 5.0
const BACK := 7.0
## L'aura du Chantre s'anime tant qu'un ennemi est à moins de cette distance.
const CHANT_ALERT := 36.0

## Chantres vivants à ce tick (Combat.update_units) : positions pour le bonus de dégâts.
static var _chantres: Array[Vector2] = []


static func refresh(alive: Array[Unit]) -> void:
	_chantres.clear()
	for u: Unit in alive:
		if u.role == "chantre" and not u.hidden:
			_chantres.append(u.pos())


## Multiplicateur des dégâts d'un allié : dans le rayon d'un Chantre (une seule fois).
static func damage_bonus(src: Unit) -> float:
	if _chantres.is_empty() or src == null or src.is_enemy():
		return 1.0
	var r: float = Catalog.MAGE["chantre"]["radius"]
	for p: Vector2 in _chantres:
		if p.distance_squared_to(src.pos()) <= r * r:
			return float(Catalog.MAGE["chantre"]["bonus"])
	return 1.0


static func hexed(e: Enemy) -> bool:
	return e.hexed_until > GameState.sim_time


## Armure d'un ennemi, abaissée s'il est envoûté.
static func armor_of(e: Enemy) -> float:
	return maxf(0.0, e.armor - float(Catalog.MAGE["envouteur"]["armor"])) if hexed(e) else e.armor


static func act(sim: Simulation, u: Unit, dt: float, alive: Array[Unit]) -> void:
	# Recul au contact (sauf ordre de déplacement en cours) : il s'écarte de l'ennemi le plus proche.
	var near: Enemy = null
	var near_d := FLEE
	for e: Enemy in GameState.enemies:
		if e.hp <= 0.0 or e.neutral or e.hidden:
			continue
		var d := Combat.hyp(e.x - u.x, e.z - u.z)
		if d < near_d:
			near_d = d
			near = e
	if near != null and not u.force_move:
		var away := (u.pos() - near.pos()).normalized()
		if away == Vector2.ZERO:
			away = Vector2.UP
		var to := u.pos() + away * BACK
		u.tx = to.x
		u.tz = to.y
	if Combat.hyp(u.x - u.tx, u.z - u.tz) > 0.3:
		sim.move(u, sim.steer(u, Vector2(u.tx, u.tz)), dt)
	match u.role:
		"guerisseuse":
			_heal(u, dt, alive)
		"chantre":
			_chant(u)
		"envouteur":
			_hex(sim, u)


static func _heal(u: Unit, dt: float, alive: Array[Unit]) -> void:
	var M: Dictionary = Catalog.MAGE["guerisseuse"]
	var best: Unit = null
	var worst := 1.0
	for t: Unit in alive:
		if t.hidden or t.hp >= t.max_hp:
			continue
		var ratio := t.hp / t.max_hp
		if ratio < worst and Combat.hyp(t.x - u.x, t.z - u.z) <= float(M["reach"]):
			worst = ratio
			best = t
	u.memo.erase("heal_target")
	if best == null:
		return
	best.hp = minf(best.max_hp, best.hp + float(M["rate"]) * dt)
	best.healed_at = GameState.sim_time
	u.working = true
	u.memo["heal_target"] = best.pos()
	if best != u and absf(best.x - u.x) > 0.3:
		u.face = -1 if best.x < u.x else 1


static func _chant(u: Unit) -> void:
	for e: Enemy in GameState.enemies:
		if e.hp > 0.0 and not e.neutral and Combat.hyp(e.x - u.x, e.z - u.z) <= CHANT_ALERT:
			u.working = true
			return


static func _hex(sim: Simulation, u: Unit) -> void:
	var M: Dictionary = Catalog.MAGE["envouteur"]
	var now := GameState.sim_time
	# Geste tenu un peu plus d'une seconde après le sort.
	if now < float(u.memo.get("cast_until", -INF)):
		u.working = true
	if u.ability > 0.0:
		return
	var target: Enemy = null
	var best := float(M["reach"])
	for e: Enemy in GameState.enemies:
		if e.hp <= 0.0 or e.neutral or e.hidden or hexed(e):
			continue
		var d := Combat.hyp(e.x - u.x, e.z - u.z)
		if d < best and (sim.world == null or sim.world.fog.visible_at(e.pos())):
			best = d
			target = e
	if target == null:
		return
	var until := now + float(M["time"])
	for e: Enemy in GameState.enemies:
		if e.hp > 0.0 and e.pos().distance_to(target.pos()) <= float(M["spread"]):
			e.hexed_until = until
	u.ability = float(M["cd"])
	u.memo["cast_until"] = now + 1.4
	u.working = true
	u.face = -1 if target.x < u.x else 1
	Combat.zone(target.x, target.z, float(M["spread"]), Color("#9a7aff"))
	Sfx.at("recherche", target.x, target.z)
