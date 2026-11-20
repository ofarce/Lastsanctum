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
## Chiens de la Bête (demande du 2026-11-20) : le crachat est leur seule attaque (plus de morsure). Ils crachent
## une boule de feu vers leur cible, ou vers l'Ancre faute de cible (SPIT), jusqu'à leur portée de tir (32 unités,
## Catalog.ENEMY.beast.range), ligne de tir dégagée, en courant comme à l'arrêt. Le crachat est annoncé SPIT.warn s
## (braise dans la gueule, trait au sol : planche « Visibilité des balles », piste 6·B) puis part de la gueule
## (mouth), vers la cible là où elle est alors. La boule touche sa cible, quelle qu'elle soit (un adepte ne l'esquive
## que s'il bouge), ou l'Exilé incarné s'il croise sa route.
## Archer à bout portant (même bilan) : sous ARCHER_CLOSE unités, son annonce dure ARCHER_CLOSE_WINDUP fois plus.
## Motifs statiques (planche « Motifs statiques », bilan du 2026-11-20 : 1·A, 2·V, 3·C et réglages gardés) : ils ne
## visent pas l'Exilé, ils suivent l'ennemi. Seulement si l'Exilé incarné est à moins de NEAR unités.
## - Fanatique (creep) : à sa mort, quel que soit le tueur, un anneau d'ichor est annoncé ICHOR.warn s sur le corps
##   (« ichor_warn »), puis part : ICHOR.n places dont ICHOR.gap vides, la brèche dans le dos du mort (côté opposé à
##   son regard) ; gouttes lentes « ichor ».
## - Strazhar : à chaque course, il fiche un éclat d'os-chair tous les BONE.every unités (« spike », inoffensif : c'est
##   l'annonce) ; BONE.delay s plus tard, l'éclat part en deux (« bone ») vers l'arrière, à ± BONE.spread de sa trace :
##   un sillage en V. Rien à l'arrêt ni en frappant.
## Rendu : EffectsDrawer._enemy_shots.

## Annonce du tir (s), divisée par la cadence de la vague.
const WINDUP := {"archer": 0.4, "soldier": 0.45, "spitter": 0.5}
const ARCHER_CLOSE := 3.0
const ARCHER_CLOSE_WINDUP := 2.0
## Vitesses en unités/s, portées en unités, rayons en unités.
const ARROW := {"speed": 17.0, "range": 32.0, "r": 0.25}
const ORB := {"speed": 5.5, "count": 3, "spread": 0.3, "life": 12.8, "r": 0.8}
const PILUM := {"flight": 0.75, "radius": 1.1, "shards": 4, "shard_speed": 6.0, "shard_life": 0.6, "shard_r": 0.25, "shard_damage": 0.5}
## Crachat des chiens : dégâts en part de la morsure, attente entre deux crachats (every + hasard jitter).
## warn : annonce (s) ; gueule : MOUTH_AHEAD unités devant le chien (côté où il regarde), MOUTH_UP au nord des pieds
## (la boule vole à SHOT_LIFT px du sol : la gueule du sprite beast est à 24 px devant et 16 px au-dessus des pieds).
## core : distance à laquelle une boule visant l'Ancre la touche.
## count boules en cône, écartées de spread radians ; seule la boule centrale éclaire (Lighting).
const SPIT := {"count": 3, "spread": 0.22, "speed": 9.0, "r": 0.675, "damage": 1.0, "every": 1.6, "jitter": 0.8, "first": 0.5, "warn": 0.3, "core": 0.8}
const MOUTH_AHEAD := 3.0
const MOUTH_UP := 0.25
const HIT := 0.375
## Motifs statiques : distance maximale de l'Exilé incarné pour qu'ils se forment.
const NEAR := 14.0
## Anneau d'ichor du Fanatique. r0 : rayon de départ ; damage : part du coup du Fanatique.
const ICHOR := {"n": 12, "gap": 3, "r0": 1.0, "speed": 3.5, "life": 2.8, "r": 0.3, "warn": 0.45, "damage": 0.5}
## Sillage du Strazhar. every : unités entre deux éclats ; delay : s fichés ; spread : écart de chaque éclat à
## l'arrière de la course (rad, 50°) ; slow : sous cette part de sa vitesse, il ne court pas (pas d'éclat) ;
## damage : part du coup du Strazhar.
const BONE := {"every": 2.4, "delay": 1.0, "speed": 5.0, "life": 1.2, "r": 0.3, "spread": 0.87, "slow": 0.4, "damage": 0.25}
## Invulnérabilité après un coup : 0,6 s comme contre les boss (bilan du 2026-11-20 ; avant 0,35 s).
const IFRAMES := 0.6
## Éclair d'une balle éteinte sur la roche : couleur et taille (part de l'impact habituel).
const EXTINCT := Color("#8a8e98")
const EXTINCT_SIZE := 0.7
## Plafond de balles en vol : au-delà, les plus anciennes s'éteignent.
const MAX := 160


## Durée de l'annonce si ce tir de e sur target doit partir en balles (0 = coup immédiat habituel).
static func windup(e: Enemy, target: Variant, d: float) -> float:
	if target == null or target != GameState.incarnated or not WINDUP.has(e.kind):
		return 0.0
	if e.kind == "soldier" and d <= Combat.MELEE_REACH:
		return 0.0
	if e.kind == "archer" and d < ARCHER_CLOSE:
		return WINDUP[e.kind] * ARCHER_CLOSE_WINDUP
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


## L'Exilé incarné, s'il peut être visé (vivant, visible), sinon null.
static func _exile() -> Unit:
	var u := GameState.incarnated
	if u == null or not u.alive() or u.hidden:
		return null
	return u


## Angles (monde) des gouttes d'un anneau d'ichor dont la brèche est centrée sur back.
static func ichor_angles(back: float) -> Array[float]:
	var out: Array[float] = []
	var n: int = ICHOR["n"]
	var step := TAU / n
	for i in n:
		var a := back + i * step
		if absf(wrapf(a - back, -PI, PI)) < ICHOR["gap"] / 2.0 * step - 0.001:
			continue
		out.append(a)
	return out


## Un ennemi vient de mourir (Combat.finish_tick) : le Fanatique lâche son anneau d'ichor, annoncé sur le corps.
static func on_death(e: Enemy) -> void:
	if e.kind != "creep":
		return
	var u := _exile()
	if u == null or u.pos().distance_to(e.pos()) > NEAR:
		return
	var now := GameState.sim_time
	# Brèche dans le dos : à l'opposé du regard (le corps est projeté de ce côté, UnitView.DEATH_KICK).
	var back := PI if e.face >= 0 else 0.0
	_add({"kind": "ichor_warn", "x": e.x, "z": e.z, "back": back, "dmg": e.damage * ICHOR["damage"],
		"born": now, "until": now + ICHOR["warn"]})


## Sillage d'un Strazhar qui court près de l'Exilé incarné : un éclat fiché tous les BONE.every unités parcourues.
static func _trail(e: Enemy, u: Unit, now: float) -> void:
	if u == null or e.stun > 0.0 or e.strike_at != INF or u.pos().distance_to(e.pos()) > NEAR:
		e.trail_from = null
		return
	if e.trail_from == null:
		e.trail_from = e.pos()
		e.trail_t = now
		return
	var from: Vector2 = e.trail_from
	var run := e.pos() - from
	var l := run.length()
	var every: float = BONE["every"]
	if l < every:
		return
	# Trop lent depuis le dernier éclat (combat, piétinement) ou saut (téléportation) : le sillage repart d'ici.
	if l > every * 3.0 or l / maxf(now - e.trail_t, 0.001) < BONE["slow"] * e.speed:
		e.trail_from = e.pos()
		e.trail_t = now
		return
	var d := run / l
	var at := from + d * every
	e.trail_from = at
	e.trail_t = now
	var back := (-d).angle()
	_add({"kind": "spike", "x": at.x, "z": at.y, "a1": back + BONE["spread"], "a2": back - BONE["spread"],
		"lean": 1.0 if int(at.x * 7.0 + at.y * 3.0) % 2 == 0 else -1.0, "dmg": e.damage * BONE["damage"],
		"born": now, "until": now + BONE["delay"]})


## Gueule d'un chien (point au sol d'où part la boule) : devant lui, du côté de sa cible s'il en a une.
static func mouth(e: Enemy) -> Vector2:
	var side := float(e.face)
	var tg: Variant = e.spit_target
	if tg != null and absf(tg.x - e.x) > 0.3:
		side = signf(tg.x - e.x)
	elif e.spit_core and absf(CaveShape.CORE.x - e.x) > 0.3:
		side = signf(CaveShape.CORE.x - e.x)
	return Vector2(e.x + side * MOUTH_AHEAD, e.z - MOUTH_UP)


## Crachat d'un chien sur target, à distance d, si son heure est venue : l'annonce commence (le tir part dans
## tick, à e.spit_fire_at).
## target null : l'Ancre, visée en aim (bord de son socle).
static func spit(sim: Simulation, e: Enemy, target: Unit, aim: Vector2, d: float) -> void:
	var now := GameState.sim_time
	if e.spit_fire_at != INF:
		return
	if e.spit_at == -INF:
		# Premier crachat décalé d'un chien à l'autre : la meute ne tire pas d'un seul bloc.
		# Court : à sa vitesse, le chien est au contact en une seconde.
		e.spit_at = now + sim.rng.randf() * SPIT["first"]
		return
	if now < e.spit_at or e.stun > 0.0 or d > e.reach:
		return
	if not sim.combat.clear_shot(e.pos(), aim):
		return
	e.spit_at = now + SPIT["every"] + sim.rng.randf() * SPIT["jitter"]
	e.spit_fire_at = now + SPIT["warn"]
	e.spit_target = target
	e.spit_core = target == null


## Fin de l'annonce : la boule part de la gueule vers la cible, si le chien et la cible sont encore là.
static func _spit_fire(sim: Simulation, e: Enemy, now: float) -> void:
	var target: Variant = e.spit_target
	var core := e.spit_core
	var from := mouth(e)
	e.spit_fire_at = INF
	e.spit_target = null
	e.spit_core = false
	if e.hp <= 0.0 or e.stun > 0.0:
		return
	if not core and (target == null or not target.alive() or target.hidden):
		return
	var to: Vector2 = Capsule.anchor_edge(e.pos()) if core else target.pos()
	if not sim.combat.clear_shot(e.pos(), to):
		return
	var a := (to - from).angle()
	var n: int = SPIT["count"]
	for i in n:
		var k := i - (n - 1) / 2.0
		var c: float = a + k * SPIT["spread"]
		var b := {"kind": "fire", "x": from.x, "z": from.y, "vx": cos(c) * SPIT["speed"], "vz": sin(c) * SPIT["speed"],
			"r": SPIT["r"], "dmg": e.damage * SPIT["damage"], "born": now, "until": now + e.reach / SPIT["speed"],
			"target": target, "lit": k == 0.0, "seed": sim.rng.randi()}
		if core:
			b["core"] = to
		_add(b)
	Sfx.at("flammes", e.x, e.z)


static func _add(b: Dictionary) -> void:
	GameState.enemy_shots.append(b)
	if GameState.enemy_shots.size() > MAX:
		GameState.enemy_shots.pop_front()


## Vol des balles, extinction sur la roche, arrivée des pilums, touche sur l'Exilé incarné.
static func tick(sim: Simulation, dt: float) -> void:
	var now := GameState.sim_time
	var u := _exile()
	for e: Enemy in GameState.enemies:
		if e.spit_fire_at <= now:
			_spit_fire(sim, e, now)
		if e.kind == "strazhar":
			_trail(e, u, now)
	if GameState.enemy_shots.is_empty():
		return
	var ts: Variant = sim.world.terrain_state if sim.world != null else null
	var keep: Array[Dictionary] = []
	var landed: Array[Dictionary] = []
	for b: Dictionary in GameState.enemy_shots:
		# Pilum en vol, anneau d'ichor annoncé, éclat fiché : immobiles et inoffensifs jusqu'à leur échéance.
		if b["kind"] == "pilum" or b["kind"] == "ichor_warn" or b["kind"] == "spike":
			if now >= b["until"]:
				landed.append(b)
			else:
				keep.append(b)
			continue
		if now >= b["until"]:
			continue
		b["x"] += b["vx"] * dt
		b["z"] += b["vz"] * dt
		# Boule de feu visant l'Ancre : elle l'entame en arrivant au bord de son socle.
		if b.has("core") and (b["core"] as Vector2).distance_to(Vector2(b["x"], b["z"])) < SPIT["core"]:
			GameState.core_hp = maxf(0.0, GameState.core_hp - b["dmg"])
			Combat.flash(b["x"], b["z"], Color("#e17b63"))
			continue
		if ts != null and not ts.walkable(b["x"], b["z"]) and not ts.water_at(b["x"], b["z"]):
			# Extinction : petit éclair gris (piste 5·B ; avant : jaune #f0cc66, la couleur des annonces).
			Combat.flash(b["x"], b["z"], EXTINCT, EXTINCT_SIZE)
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
		if b["kind"] == "ichor_warn":
			_ichor_ring(b, now)
			continue
		if b["kind"] == "spike":
			for a: float in [b["a1"], b["a2"]]:
				_add({"kind": "bone", "x": b["x"], "z": b["z"], "vx": cos(a) * BONE["speed"], "vz": sin(a) * BONE["speed"],
					"r": BONE["r"], "dmg": b["dmg"], "born": now, "until": now + BONE["life"]})
			continue
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


## Fin de l'annonce de l'anneau d'ichor : les gouttes partent du rayon ICHOR.r0 autour du corps.
static func _ichor_ring(b: Dictionary, now: float) -> void:
	for a: float in ichor_angles(b["back"]):
		var d := Vector2(cos(a), sin(a))
		_add({"kind": "ichor", "x": b["x"] + d.x * ICHOR["r0"], "z": b["z"] + d.y * ICHOR["r0"],
			"vx": d.x * ICHOR["speed"], "vz": d.y * ICHOR["speed"], "r": ICHOR["r"], "dmg": b["dmg"],
			"born": now, "until": now + ICHOR["life"]})
	Sfx.at("fanatique", b["x"], b["z"])


## Coup porté à l'Exilé incarné, sauf pendant son invulnérabilité ; renvoie s'il a porté.
static func _hurt(sim: Simulation, u: Unit, dmg: float, now: float) -> bool:
	if now < GameState.martyre_iframe_until:
		return false
	sim.combat.hit_unit(u, dmg)
	GameState.martyre_iframe_until = now + IFRAMES
	return true
