class_name Martyre
extends RefCounted
## Premier boss : la Martyre de Byrsa (piste 4 de planches/boss-propositions.html, atlas martyre_*.png).
##
## Quand la menace atteint MENACE, elle apparaît seule à l'entrée sud ; la suite de l'assaut en cours est
## annulée et aucune vague ne part tant qu'elle vit. Elle lève aussitôt un bouclier circulaire de
## DOME_CELLS cases de diamètre centré sur elle (rendu : world/arena/martyre_dome.gd) :
## - invulnérable : seuls les coups de l'Ingénieur, porté depuis l'intérieur, la blessent (Combat.damage) ;
## - rien ne vise à travers : une cible n'est visée que si elle est du même côté que le tireur
##   (Combat.target_closest, ciblage des ennemis) ;
## - seul l'Ingénieur le traverse : les autres unités, alliées comme ennemies, sont repoussées au bord.
## Le combat singulier commence quand l'Ingénieur entre. Elle marche sur lui et frappe du bâton :
## l'impact tombe IMPACT s après le début du geste et fait DAMAGE à l'Ingénieur s'il est encore à portée
## (on peut esquiver en s'éloignant). S'il ressort, elle regagne le centre et attend, sans se soigner.
## L'objectif « Éliminer la Martyre de Byrsa en combat singulier » (Quests) dure jusqu'à sa mort.

const KIND := "martyre"
const MENACE := 500
const CELL := 4.0
## Bouclier : 24 cases de diamètre, soit 48 unités de rayon.
const DOME_CELLS := 24
const RADIUS := DOME_CELLS * CELL / 2.0
## Sur la route du sud, là où montent les assauts, assez loin du bord du monde (z = 72) pour que tout le
## bouclier tienne sur la carte.
const SPAWN := Vector2(0.0, 22.0)
const DAMAGE := 10.0
## Délai entre le début de la frappe et l'impact (image 12 sur 24 de martyre_attack, à 24 i/s).
const IMPACT := 0.5
## Marge de portée tolérée à l'impact : au-delà, le coup est esquivé.
const DODGE := 0.8
## Les autres unités sont rejetées à cette distance au-delà du bord.
const EDGE := 0.6
## Effondrement du bouclier à la mort de la Martyre (rendu).
const COLLAPSE := 1.4

const QUOTE_WAIT := "Un dôme d’or s’est levé au sud. La Martyre de Byrsa m’attend : personne d’autre ne peut passer."
const QUOTE_DUEL := "Son bâton est lent. Je m’écarte quand il se lève, je frappe quand il retombe."
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
	if now >= GameState.martyre_hit_at:
		GameState.martyre_hit_at = INF
		Combat.zone(e.x + e.face * 1.6, e.z, 2.6, Color("#e2382e"))
		if u != null and Combat.dist(e, u) <= e.reach + DODGE:
			sim.combat.damage(u, DAMAGE)
			Combat.flash(u.x, u.z, Color("#e17b63"))
	if GameState.martyre_hit_at != INF:
		return
	if u == null:
		if e.pos().distance_to(center()) > 1.0:
			_walk(sim, e, center(), dt)
		return
	var d := Combat.dist(e, u)
	if d > e.reach:
		_walk(sim, e, u.pos(), dt)
		e.face = -1 if u.x < e.x else 1
	elif e.cooldown <= 0.0:
		e.face = -1 if u.x < e.x else 1
		e.attack_started = now
		e.cooldown = Catalog.ENEMY[KIND]["cd"]
		GameState.martyre_hit_at = now + IMPACT


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
