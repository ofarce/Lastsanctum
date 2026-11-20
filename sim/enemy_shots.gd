class_name EnemyShots
extends RefCounted
## Tirs esquivables des ennemis à distance contre l'Exilé incarné (demande du 2026-11-20 : chaque ennemi
## apporte un geste à la logique « bullet hell »). Contre toute autre cible (adeptes, Ancre), l'archer, le soldat
## et le Thuriféraire touchent toujours à coup sûr (Combat.arrow, pilum, spell). Contre l'Exilé incarné, le tir
## est annoncé (WINDUP, l'ennemi reste campé) puis part en vraies balles, GameState.enemy_shots :
## - archer : une flèche droite et rapide vers le point où se tenait l'Exilé à l'annonce ;
## - soldat : un pilum en cloche vers ce même point ; il ne touche qu'à l'arrivée (rayon PILUM.radius), puis
##   quatre éclats partent en croix ;
## - Thuriféraire : trois orbes lents en éventail, visés au moment du départ.
## Les balles s'éteignent sur la roche et ne touchent que l'Exilé incarné (rayon HIT, comme les balles de la
## Martyre). Les dégâts sont ceux du coup d'origine (Combat.hit_unit : bouclier, garde, armure). Après un coup,
## IFRAMES s d'invulnérabilité (GameState.martyre_iframe_until, partagé avec les boss : l'Ingénieur clignote).
## Chiens de la Bête (demande du 2026-11-20) : en pleine course, sans annonce, ils crachent une petite boule de
## feu vers leur cible (SPIT) quand elle est entre near et far unités, ligne de tir dégagée. La boule touche sa
## cible, quelle qu'elle soit (un adepte ne l'esquive que s'il bouge), ou l'Exilé incarné s'il croise sa route.
## Rendu : EffectsDrawer._enemy_shots.

## Annonce du tir (s), divisée par la cadence de la vague.
const WINDUP := {"archer": 0.4, "soldier": 0.45, "spitter": 0.5}
## Vitesses en unités/s, portées en unités, rayons en unités.
const ARROW := {"speed": 17.0, "range": 16.0, "r": 0.25}
const ORB := {"speed": 5.5, "count": 3, "spread": 0.3, "life": 3.2, "r": 0.4}
const PILUM := {"flight": 0.75, "radius": 1.1, "shards": 4, "shard_speed": 6.0, "shard_life": 0.6, "shard_r": 0.25, "shard_damage": 0.5}
## Crachat des chiens : dégâts en part de la morsure, attente entre deux crachats (every + hasard jitter).
const SPIT := {"speed": 9.0, "range": 11.0, "r": 0.22, "near": 3.0, "far": 9.0, "damage": 0.75, "every": 2.4, "jitter": 1.2}
const HIT := 0.375
const IFRAMES := 0.35
## Plafond de balles en vol : au-delà, les plus anciennes s'éteignent.
const MAX := 160


## Durée de l'annonce si ce tir de e sur target doit partir en balles (0 = coup immédiat habituel).
static func windup(e: Enemy, target: Variant, d: float) -> float:
	if target == null or target != GameState.incarnated or not WINDUP.has(e.kind):
		return 0.0
	if e.kind == "soldier" and d <= Combat.MELEE_REACH:
		return 0.0
	return WINDUP[e.kind]


## Fin de l'annonce : les balles partent. aim : point visé à l'annonce.
static func fire(sim: Simulation, e: Enemy, aim: Vector2) -> void:
	var now := GameState.sim_time
	var from := e.pos()
	e.face = -1 if aim.x < e.x else 1
	match e.kind:
		"archer":
			var a := (aim - from).angle()
			_add({"kind": "arrow", "x": e.x, "z": e.z, "vx": cos(a) * ARROW["speed"], "vz": sin(a) * ARROW["speed"],
				"r": ARROW["r"], "dmg": e.damage, "born": now, "until": now + ARROW["range"] / ARROW["speed"]})
			Sfx.at("arc", e.x, e.z)
		"soldier":
			_add({"kind": "pilum", "x": e.x, "z": e.z, "tx": aim.x, "tz": aim.y, "vx": 0.0, "vz": 0.0, "face": e.face,
				"r": 0.0, "dmg": e.damage, "born": now, "until": now + PILUM["flight"]})
			Sfx.at("pilum", e.x, e.z)
		"spitter":
			var u := GameState.incarnated
			if u != null and u.alive() and not u.hidden:
				aim = u.pos()
			var a := (aim - from).angle()
			var n: int = ORB["count"]
			for i in n:
				var b: float = a + (i - (n - 1) / 2.0) * ORB["spread"]
				_add({"kind": "orb", "x": e.x, "z": e.z, "vx": cos(b) * ORB["speed"], "vz": sin(b) * ORB["speed"],
					"r": ORB["r"], "dmg": e.damage, "born": now, "until": now + ORB["life"], "seed": sim.rng.randi()})
			Sfx.at("sort_lumiere", e.x, e.z)


## Crachat d'un chien sur target, à distance d, si son heure est venue.
static func spit(sim: Simulation, e: Enemy, target: Unit, d: float) -> void:
	var now := GameState.sim_time
	if e.spit_at == -INF:
		# Premier crachat décalé d'un chien à l'autre : la meute ne tire pas d'un seul bloc.
		e.spit_at = now + sim.rng.randf() * SPIT["every"]
		return
	if now < e.spit_at or e.stun > 0.0 or d < SPIT["near"] or d > SPIT["far"]:
		return
	if not sim.combat.clear_shot(e.pos(), target.pos()):
		return
	e.spit_at = now + SPIT["every"] + sim.rng.randf() * SPIT["jitter"]
	var a := (target.pos() - e.pos()).angle()
	_add({"kind": "fire", "x": e.x + cos(a) * 1.2, "z": e.z + sin(a) * 1.2, "vx": cos(a) * SPIT["speed"], "vz": sin(a) * SPIT["speed"],
		"r": SPIT["r"], "dmg": e.damage * SPIT["damage"], "born": now, "until": now + SPIT["range"] / SPIT["speed"],
		"target": target, "seed": sim.rng.randi()})
	Sfx.at("flammes", e.x, e.z)


static func _add(b: Dictionary) -> void:
	GameState.enemy_shots.append(b)
	if GameState.enemy_shots.size() > MAX:
		GameState.enemy_shots.pop_front()


## Vol des balles, extinction sur la roche, arrivée des pilums, touche sur l'Exilé incarné.
static func tick(sim: Simulation, dt: float) -> void:
	if GameState.enemy_shots.is_empty():
		return
	var now := GameState.sim_time
	var u := GameState.incarnated
	if u != null and (not u.alive() or u.hidden):
		u = null
	var ts: Variant = sim.world.terrain_state if sim.world != null else null
	var keep: Array[Dictionary] = []
	var landed: Array[Dictionary] = []
	for b: Dictionary in GameState.enemy_shots:
		if b["kind"] == "pilum":
			if now >= b["until"]:
				landed.append(b)
			else:
				keep.append(b)
			continue
		if now >= b["until"]:
			continue
		b["x"] += b["vx"] * dt
		b["z"] += b["vz"] * dt
		if ts != null and not ts.walkable(b["x"], b["z"]) and not ts.water_at(b["x"], b["z"]):
			Combat.flash(b["x"], b["z"], Color("#f0cc66"))
			continue
		# Boule de feu : elle touche aussi la cible qu'elle visait (adepte), sans invulnérabilité.
		var tg: Variant = b.get("target")
		if tg != null and tg != u and tg.alive() and not tg.hidden:
			var tr: float = HIT + b["r"]
			if (tg.pos() - Vector2(b["x"], b["z"])).length_squared() < tr * tr:
				sim.combat.hit_unit(tg, b["dmg"])
				continue
		if u != null:
			var reach: float = HIT + b["r"]
			var dx: float = u.x - b["x"]
			var dz: float = u.z - b["z"]
			if dx * dx + dz * dz < reach * reach and _hurt(sim, u, b["dmg"], now):
				if b["kind"] == "arrow":
					Sfx.at("fleche_impact", u.x, u.z)
				continue
		keep.append(b)
	GameState.enemy_shots = keep
	for b: Dictionary in landed:
		var at := Vector2(b["tx"], b["tz"])
		Combat._fx({"type": "arrowhit", "x": at.x, "z": at.y, "age": 0.0, "duration": 0.24, "seed": sim.rng.randi()})
		Sfx.at("fleche_impact", at.x, at.y)
		if u != null and u.pos().distance_to(at) < PILUM["radius"]:
			_hurt(sim, u, b["dmg"], now)
		# Éclats en croix, alignés sur le jet.
		var a := (at - Vector2(b["x"], b["z"])).angle()
		var n: int = PILUM["shards"]
		for i in n:
			var c: float = a + i * TAU / n
			_add({"kind": "shard", "x": at.x, "z": at.y, "vx": cos(c) * PILUM["shard_speed"], "vz": sin(c) * PILUM["shard_speed"],
				"r": PILUM["shard_r"], "dmg": b["dmg"] * PILUM["shard_damage"], "born": now, "until": now + PILUM["shard_life"]})


## Coup porté à l'Exilé incarné, sauf pendant son invulnérabilité ; renvoie s'il a porté.
static func _hurt(sim: Simulation, u: Unit, dmg: float, now: float) -> bool:
	if now < GameState.martyre_iframe_until:
		return false
	sim.combat.hit_unit(u, dmg)
	GameState.martyre_iframe_until = now + IFRAMES
	return true
