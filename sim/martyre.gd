class_name Martyre
extends RefCounted
## Premier boss : la Martyre de Byrsa (planches/martyre-v3-propositions.html : modèle C2 « L'armure cède »,
## fissure 4.1 « Faille en relief », sceaux 5.3 « Rai du ciel » ; atlas martyre_*.png exportés par
## planches/martyre-v3-export.html, animations et attaques 30 % plus rapides que la planche, SPEED).
##
## Quand la menace atteint MENACE, elle apparaît seule sur la route du sud ; la suite de l'assaut en cours est
## annulée et aucune vague ne part tant qu'elle vit. Elle lève aussitôt un bouclier circulaire de
## DOME_CELLS cases de diamètre centré sur elle (rendu : world/arena/martyre_dome.gd) :
## - invulnérable : seuls les coups de l'Ingénieur, porté depuis l'intérieur, la blessent (Combat.damage) ;
## - rien ne vise à travers : une cible n'est visée que si elle est du même côté que le tireur
##   (Combat.target_closest, ciblage des ennemis) ;
## - seul l'Ingénieur le traverse : les autres unités, alliées comme ennemies, sont repoussées au bord.
## Le combat singulier commence quand l'Ingénieur entre. Elle a trois attaques, chacune annoncée par un geste :
## - frappe au contact : l'impact tombe IMPACT s après le début du geste, DAMAGE si l'Ingénieur est encore à
##   portée (on esquive en s'éloignant) ;
## - fissure (FISSURE), à distance : même geste ; au point d'impact, une faille court au sol vers la
##   position qu'avait l'Ingénieur au début du geste, puis la lumière jaillit au bout : dégâts et
##   étourdissement s'il s'y tient encore ;
## - sceaux (SEALS), à distance : elle lève la main ; trois cercles s'inscrivent sous l'Ingénieur et de part
##   et d'autre, un rai du ciel les vise pendant la charge, puis la lumière s'abat sur chacun.
## S'il ressort du bouclier, elle regagne le centre et attend, sans se soigner ; ses effets en cours
## n'atteignent que l'Ingénieur resté sous le bouclier. Effets en cours : GameState.martyre_fx (rendu :
## world/arena/martyre_fx.gd). L'objectif « Éliminer la Martyre de Byrsa en combat singulier » (Quests)
## dure jusqu'à sa mort.

const KIND := "martyre"
const MENACE := 500
const CELL := 4.0
## Bouclier : 24 cases de diamètre, soit 48 unités de rayon.
const DOME_CELLS := 24
const RADIUS := DOME_CELLS * CELL / 2.0
## Sur la route du sud, là où montent les assauts, assez loin du bord du monde (z = 72) pour que tout le
## bouclier tienne sur la carte.
const SPAWN := Vector2(0.0, 22.0)
## Animations et attaques 30 % plus rapides que la planche.
const SPEED := 1.3
const DAMAGE := 10.0
## Délai entre le début de la frappe et l'impact du bâton (moitié de l'animation martyre_attack).
const IMPACT := 0.5 / SPEED
## Durée du geste de frappe (martyre_attack) et de l'incantation (martyre_cast) : elle reste sur place.
const STRIKE_TIME := 1.0 / SPEED
const CAST_TIME := 2.2 / SPEED
## Marge de portée tolérée à l'impact : au-delà, le coup est esquivé.
const DODGE := 0.8
## Point d'impact du bâton devant elle (unités), d'où part la fissure.
const STAFF_REACH := 2.4
## Fissure : portée de déclenchement, recharge, vitesse de la faille, dégâts et étourdissement au bout,
## rayon touché par l'éruption, durée de l'éruption puis du refroidissement.
const FISSURE := {"range": 22.0, "cd": 7.0 / SPEED, "speed": 20.0 * SPEED, "damage": 12.0, "stun": 1.0,
	"radius": 2.2, "erupt": 0.9 / SPEED, "cool": 0.9 / SPEED}
## Sceaux : portée, recharge, instant de pose après le début du geste, charge, dégâts, rayon d'un sceau,
## écart des sceaux latéraux, durée de la colonne.
const SEALS := {"range": 26.0, "cd": 9.0 / SPEED, "place": 0.6 / SPEED, "charge": 1.3 / SPEED, "damage": 14.0,
	"radius": 2.0, "spread": 5.0, "boom": 0.9 / SPEED}
## Hors de portée de mêlée mais au-delà de cette marge, elle préfère une attaque à distance.
const RANGED_MIN := 4.0
## Les autres unités sont rejetées à cette distance au-delà du bord.
const EDGE := 0.6
## Effondrement du bouclier à la mort de la Martyre (rendu).
const COLLAPSE := 1.4
## Réaction aux coups : au plus une fois par seconde.
const HURT_EVERY := 1.0

const QUOTE_WAIT := "Un dôme d’or s’est levé au sud. La Martyre de Byrsa m’attend : personne d’autre ne peut passer."
const QUOTE_DUEL := "La faille court vers moi, le ciel marque mes pas : je ne dois jamais rester où elle vise."
const QUOTE_DONE := "La Martyre est tombée et son dôme avec elle. Les assauts vont reprendre."


## La Martyre est sur le terrain, vivante : bouclier levé, vagues suspendues.
static func active() -> bool:
	return GameState.martyre != null and GameState.martyre.hp > 0.0


static func center() -> Vector2:
	return GameState.martyre_center


## p (unité, ennemi, baliste {x, z}) est-il sous le bouclier ?
static func inside(p: Variant) -> bool:
	var dx: float = p.x - GameState.martyre_center.x
	var dz: float = p.z - GameState.martyre_center.y
	return dx * dx + dz * dz < RADIUS * RADIUS


## Le bouclier sépare a et b : aucun tir ni ciblage de l'un vers l'autre.
static func blocks(a: Variant, b: Variant) -> bool:
	return active() and inside(a) != inside(b)


## Seul l'Ingénieur, sous le bouclier, peut blesser la Martyre.
static func can_hurt(src: Unit) -> bool:
	return src != null and src.role == "engineer" and inside(src)


## L'Ingénieur en duel (vivant, sorti du portail, sous le bouclier), sinon null.
static func duelist() -> Unit:
	if not active():
		return null
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden and inside(u):
			return u
	return null


## Apparition, début et fin du duel, chute : appelé à chaque pas de simulation, avant les apparitions.
static func tick(sim: Simulation) -> void:
	if GameState.ended:
		return
	match GameState.martyre_state:
		"":
			if GameState.menace >= MENACE:
				spawn(sim)
		"waiting", "duel":
			var e: Enemy = GameState.martyre
			if e == null or e.hp <= 0.0:
				GameState.martyre_state = "defeated"
				GameState.martyre_down_at = GameState.sim_time
				GameState.martyre_hit_at = INF
				GameState.martyre_cast_at = INF
				GameState.martyre_fx.clear()
				GameState.martyre = null
				sim.say(QUOTE_DONE, 4.0)
				return
			var u := duelist()
			if GameState.martyre_state == "waiting" and u != null:
				GameState.martyre_state = "duel"
				sim.say("Combat singulier : la Martyre de Byrsa lève son bâton.", 3.0)
			elif GameState.martyre_state == "duel" and u == null:
				GameState.martyre_state = "waiting"
				GameState.martyre_hit_at = INF
				GameState.martyre_cast_at = INF


static func spawn(sim: Simulation) -> Enemy:
	var p := SPAWN
	if not sim.state().walkable(p.x, p.y):
		p = sim.state().push_out_of_rock(p)
	var e := Enemy.make(KIND, p.x, p.y, 1.0)
	e.face = -1
	GameState.enemies.append(e)
	GameState.martyre = e
	GameState.martyre_state = "waiting"
	GameState.martyre_center = p
	GameState.martyre_at = GameState.sim_time
	GameState.martyre_hit_at = INF
	GameState.martyre_cast_at = INF
	GameState.martyre_busy_until = -INF
	GameState.martyre_fx.clear()
	# Les attaques à distance ne partent pas dès l'entrée de l'Ingénieur.
	GameState.martyre_ready = {"fissure": GameState.sim_time + 2.0, "seals": GameState.sim_time + 4.0}
	# Elle vient seule : le reste de l'assaut en cours n'entre pas.
	GameState.spawn_queue.clear()
	GameState.next_wave = 0.0
	Combat.zone(p.x, p.y, 6.0, Color("#f0cc66"))
	Combat.flash(p.x, p.y, Color("#e2382e"))
	sim.say("La Martyre de Byrsa est entrée par le sud. Son bouclier ne laisse passer que moi.", 4.0)
	enforce(sim)
	return e


## Comportement de la Martyre (à la place de celui des autres ennemis, Combat.update_enemies).
static func act(sim: Simulation, e: Enemy, dt: float) -> void:
	e.cooldown -= dt
	e.stun = 0.0
	var u := duelist()
	var now := GameState.sim_time
	_resolve_staff(sim, e, u, now)
	_resolve_cast(e, u, now)
	update_fx(sim, u, now)
	if now < GameState.martyre_busy_until:
		return
	if u == null:
		if e.pos().distance_to(center()) > 1.0:
			_walk(sim, e, center(), dt)
		return
	var d := Combat.dist(e, u)
	var ready: Dictionary = GameState.martyre_ready
	if d <= e.reach:
		if e.cooldown <= 0.0:
			_start_strike(e, u, "melee", now)
		return
	if d > RANGED_MIN:
		# La plus ancienne attaque prête d'abord, chacune dans sa portée.
		var can_f: bool = d <= FISSURE["range"] and now >= ready["fissure"]
		var can_s: bool = d <= SEALS["range"] and now >= ready["seals"]
		if can_f and (not can_s or ready["fissure"] <= ready["seals"]):
			_start_strike(e, u, "fissure", now)
			ready["fissure"] = now + FISSURE["cd"]
			return
		if can_s:
			e.face = -1 if u.x < e.x else 1
			e.cast_started = now
			GameState.martyre_cast_at = now
			GameState.martyre_busy_until = now + CAST_TIME
			ready["seals"] = now + SEALS["cd"]
			return
	_walk(sim, e, u.pos(), dt)
	e.face = -1 if u.x < e.x else 1


static func _start_strike(e: Enemy, u: Unit, kind: String, now: float) -> void:
	e.face = -1 if u.x < e.x else 1
	e.attack_started = now
	e.cooldown = Catalog.ENEMY[KIND]["cd"]
	GameState.martyre_hit_at = now + IMPACT
	GameState.martyre_hit_kind = kind
	GameState.martyre_aim = u.pos()
	GameState.martyre_busy_until = now + STRIKE_TIME


## Impact du bâton : coup au contact, ou départ de la fissure vers la position visée.
static func _resolve_staff(sim: Simulation, e: Enemy, u: Unit, now: float) -> void:
	if now < GameState.martyre_hit_at:
		return
	GameState.martyre_hit_at = INF
	var at := e.pos() + Vector2(e.face * STAFF_REACH, 0.0)
	Combat.zone(at.x, at.y, 2.6, Color("#e2382e"))
	if GameState.martyre_hit_kind == "fissure":
		var to: Vector2 = GameState.martyre_aim
		var dir := (to - at)
		var length := minf(dir.length(), FISSURE["range"])
		if length < 1.0:
			dir = Vector2(e.face, 0.0)
			length = 1.0
		var end := at + dir.normalized() * length
		GameState.martyre_fx.append({"type": "fissure", "x0": at.x, "z0": at.y, "x1": end.x, "z1": end.y,
			"at": now, "erupt": now + length / FISSURE["speed"], "seed": int(now * 1000.0) % 10000, "hit": false})
		return
	if u != null and Combat.dist(e, u) <= e.reach + DODGE:
		sim.combat.damage(u, DAMAGE)
		Combat.flash(u.x, u.z, Color("#e17b63"))


## Pose des trois sceaux, en cours d'incantation : sous l'Ingénieur et de part et d'autre, à l'est et à
## l'ouest, pour que les trois colonnes restent distinctes à l'écran.
static func _resolve_cast(e: Enemy, u: Unit, now: float) -> void:
	if GameState.martyre_cast_at == INF or now < GameState.martyre_cast_at + SEALS["place"]:
		return
	GameState.martyre_cast_at = INF
	if u == null:
		return
	var side := Vector2(SEALS["spread"], 0.0)
	for k in 3:
		var p := u.pos() + side * (k - 1)
		GameState.martyre_fx.append({"type": "seal", "x": p.x, "z": p.y, "at": now, "boom": now + SEALS["charge"],
			"index": k, "hit": false})


## Éruptions et colonnes : dégâts au moment où elles jaillissent, puis retrait une fois éteintes.
static func update_fx(sim: Simulation, u: Unit, now: float) -> void:
	var keep: Array[Dictionary] = []
	for f: Dictionary in GameState.martyre_fx:
		if f["type"] == "fissure":
			if not f["hit"] and now >= f["erupt"]:
				f["hit"] = true
				var end := Vector2(f["x1"], f["z1"])
				Combat.flash(end.x, end.y, Color("#ffa846"))
				if u != null and u.pos().distance_to(end) <= FISSURE["radius"]:
					sim.combat.damage(u, FISSURE["damage"])
					u.stunned_until = now + FISSURE["stun"]
			if now < f["erupt"] + FISSURE["erupt"] + FISSURE["cool"]:
				keep.append(f)
		else:
			if not f["hit"] and now >= f["boom"]:
				f["hit"] = true
				if u != null and u.pos().distance_to(Vector2(f["x"], f["z"])) <= SEALS["radius"]:
					sim.combat.damage(u, SEALS["damage"])
					Combat.flash(u.x, u.z, Color("#fff2b0"))
			if now < f["boom"] + SEALS["boom"]:
				keep.append(f)
	GameState.martyre_fx = keep


## Réaction aux coups (animation martyre_hit), au plus toutes les HURT_EVERY secondes.
static func hurt(e: Enemy) -> void:
	if GameState.sim_time - e.hurt_at >= HURT_EVERY:
		e.hurt_at = GameState.sim_time


static func _walk(sim: Simulation, e: Enemy, goal: Vector2, dt: float) -> void:
	var next := sim.steer(e, goal)
	var step := (next - e.pos()).limit_length(e.speed * dt)
	var p := _clamp_inside(e.pos() + step, RADIUS - 1.0)
	if sim.state().walkable(p.x, p.y):
		e.x = p.x
		e.z = p.y


static func _clamp_inside(p: Vector2, r: float) -> Vector2:
	var off := p - center()
	return center() + off.limit_length(r)


## Le bouclier repousse au bord tout ce qui n'est ni la Martyre ni l'Ingénieur.
static func enforce(sim: Simulation) -> void:
	if not active():
		return
	for u: Unit in GameState.units:
		if u.role == "engineer" or not u.alive() or u.hidden or not inside(u):
			continue
		var p := _push_out(sim, u.pos())
		u.x = p.x
		u.z = p.y
		# Il ne s'obstine pas à entrer : il attend au bord.
		u.tx = p.x
		u.tz = p.y
		u.force_move = false
	for e: Enemy in GameState.enemies:
		if e == GameState.martyre or e.hp <= 0.0 or not inside(e):
			continue
		var p := _push_out(sim, e.pos())
		e.x = p.x
		e.z = p.y


static func _push_out(sim: Simulation, p: Vector2) -> Vector2:
	var off := p - center()
	if off.length() < 0.01:
		off = Vector2(0.0, -1.0)
	var q := center() + off.normalized() * (RADIUS + EDGE)
	return q if sim.state().walkable(q.x, q.y) else sim.state().push_out_of_rock(q)


## Objectif affiché tant que la Martyre vit (Quests.objective), sinon {}.
static func objective() -> Dictionary:
	if not active():
		return {}
	var e: Enemy = GameState.martyre
	return {"id": "martyre", "quest": "La Martyre de Byrsa", "interrupt": true,
		"label": "Éliminer la Martyre de Byrsa en combat singulier",
		"quote": QUOTE_DUEL if GameState.martyre_state == "duel" else QUOTE_WAIT, "done_quote": QUOTE_DONE,
		"value": "%d PV" % ceili(e.hp), "progress": 1.0 - e.hp / e.max_hp}
