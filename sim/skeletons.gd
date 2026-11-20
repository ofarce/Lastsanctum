class_name Skeletons
extends RefCounted
## Les trois squelettes de la nuit (demande du 2026-11-20, planches/squelettes-planche.html). Un bloc = une case
## de 4 unités de monde.
##
## - À collier (kind « skeleton ») : se lève par trois. Aucun membre ne s'éloigne à plus de TETHER des deux
##   autres : la chaîne qui relie les colliers les ramène l'un vers l'autre. Touché, il lâche SHARDS éclats en
##   étoile, de vraies balles à esquiver (EnemyShots, kind « shard » : elles ne touchent que l'Exilé incarné).
## - À bubons (« skeleton_bubo ») : touché, un bubon éclate et blesse tout à moins de BURST.r, alliés, ennemis
##   et barricades, sauf les autres squelettes. Le bubon repousse en BURST.every secondes.
## - Explosif (« skeleton_bomb ») : à sa mort il tombe à genoux, puis BLAST.delay secondes plus tard le souffle
##   blesse tout à moins de BLAST.r, squelettes compris, et BLAST.balls boules de feu partent de l'épicentre en
##   étoile (EnemyShots, kind « fire » : esquivables, elles ne touchent que l'Exilé incarné).
##
## Les dégâts sont des parts des dégâts du squelette (qui montent avec la menace). Apparition : Night._flow.
## Rendu : EffectsDrawer (_skel_chains, _skel_wave).

const BLOCK := 4.0
const COLLAR := "skeleton"
const BUBO := "skeleton_bubo"
const BOMB := "skeleton_bomb"
const KINDS: Array[String] = [COLLAR, BUBO, BOMB]
## Effectif d'un groupe de colliers, et écart maximal entre deux membres.
const PACK := 3
const TETHER := 4.0 * BLOCK
## Écart entre les membres d'un trio à la levée.
const SPREAD := 5.0
## Éclats du collier : nombre, portée, vitesse, rayon, part des dégâts, délai minimal entre deux gerbes
## (un lance-flammes ne déclenche pas une gerbe par image).
const SHARDS := {"count": 6, "range": 3.0 * BLOCK, "speed": 10.0, "r": 0.25, "damage": 0.5, "every": 0.4}
const BURST := {"r": 1.0 * BLOCK, "damage": 0.75, "every": 1.0}
## delay : durée de l'agenouillement dans l'atlas de mort (0,2 s de recul + 0,6 s à genoux).
const BLAST := {"delay": 0.8, "r": 2.0 * BLOCK, "damage": 3.0, "balls": 10, "ball_range": 5.0 * BLOCK,
	"ball_speed": 20.0, "ball_r": 0.3, "ball_damage": 1.0}
const BILE := Color("#ccd24a")
const EMBER := Color("#ff7a20")


## Type du squelette qui se lève, tiré selon Catalog.NIGHT_FLOW.mix.
static func roll(rng: RandomNumberGenerator) -> String:
	var mix: Dictionary = Catalog.NIGHT_FLOW["mix"]
	var total := 0.0
	for k: String in mix:
		total += float(mix[k])
	var x: float = rng.randf() * total
	for k: String in mix:
		x -= float(mix[k])
		if x < 0.0:
			return k
	return COLLAR


## Fait lever un squelette du type donné en `at` (trois pour les colliers) ; renvoie ceux qui se sont levés.
static func raise(sim: Simulation, kind: String, at: Vector2, scaling: Dictionary, now: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var st := sim.state()
	var n := PACK if kind == COLLAR else 1
	for k in n:
		var p := at
		if k > 0:
			# Écartés d'un bon bloc : la chaîne se voit entre eux dès la sortie de terre.
			p = at + Vector2.from_angle(float(k) / n * TAU + 0.6) * SPREAD
			if not st.walkable(p.x, p.y):
				p = at
		var e := Enemy.make(kind, p.x, p.y, 0.3 + sim.rng.randf() * 0.7, scaling)
		e.beast = true
		# Il sort de terre en silhouette noire, puis prend ses couleurs (UnitView).
		e.risen_at = now
		out.append(e)
		GameState.enemies.append(e)
	if n > 1:
		for e in out:
			e.memo["pack"] = out
	return out


## Membres vivants du groupe de ce collier (lui compris), ou [] s'il est seul.
static func pack_of(e: Enemy) -> Array:
	if e.kind != COLLAR or not e.memo.has("pack"):
		return []
	return (e.memo["pack"] as Array).filter(func(o: Enemy) -> bool: return o.hp > 0.0)


## Un squelette vient de perdre des PV (Combat.damage).
static func on_hit(sim: Simulation, e: Enemy) -> void:
	var now := GameState.sim_time
	if e.kind == COLLAR:
		if now < float(e.memo.get("shards_at", -INF)):
			return
		e.memo["shards_at"] = now + float(SHARDS["every"])
		var n: int = SHARDS["count"]
		var a0 := sim.rng.randf() * TAU
		for i in n:
			var a := a0 + i * TAU / n
			EnemyShots._add({"kind": "shard", "x": e.x, "z": e.z, "vx": cos(a) * SHARDS["speed"], "vz": sin(a) * SHARDS["speed"],
				"r": SHARDS["r"], "dmg": e.damage * SHARDS["damage"], "born": now, "until": now + SHARDS["range"] / SHARDS["speed"]})
		Sfx.at("fleche_impact", e.x, e.z)
	elif e.kind == BUBO:
		if now < float(e.memo.get("burst_at", -INF)):
			return
		e.memo["burst_at"] = now + float(BURST["every"])
		Combat._fx({"type": "skel_bile", "x": e.x, "z": e.z, "r": BURST["r"], "age": 0.0, "duration": 0.6, "color": BILE})
		Sfx.at("sillon", e.x, e.z)
		_splash(sim, e.pos(), BURST["r"], e.damage * BURST["damage"], true, e)


## Un squelette vient de mourir (Combat.finish_tick) : l'explosif arme son souffle.
static func on_death(e: Enemy) -> void:
	if e.kind != BOMB:
		return
	GameState.skeleton_blasts.append({"x": e.x, "z": e.z, "at": GameState.sim_time + float(BLAST["delay"]) / maxf(e.pace, 0.01),
		"dmg": e.damage})


static func tick(sim: Simulation, _dt: float) -> void:
	_tether(sim)
	if GameState.skeleton_blasts.is_empty():
		return
	var now := GameState.sim_time
	var due: Array[Dictionary] = []
	var keep: Array[Dictionary] = []
	for b: Dictionary in GameState.skeleton_blasts:
		if now >= float(b["at"]):
			due.append(b)
		else:
			keep.append(b)
	GameState.skeleton_blasts = keep
	for b in due:
		_blast(sim, b, now)


## La chaîne : deux colliers d'un même groupe trop éloignés sont ramenés l'un vers l'autre, à parts égales.
static func _tether(sim: Simulation) -> void:
	for e: Enemy in GameState.enemies:
		if e.kind != COLLAR or e.hp <= 0.0 or not e.memo.has("pack"):
			continue
		for o: Enemy in e.memo["pack"]:
			if o == e or o.hp <= 0.0:
				continue
			var gap := o.pos() - e.pos()
			var d := gap.length()
			if d <= TETHER:
				continue
			var pull := gap / d * (d - TETHER) * 0.5
			e.x += pull.x
			e.z += pull.y
			o.x -= pull.x
			o.z -= pull.y
			sim.clamp_world(e)
			sim.clamp_world(o)


static func _blast(sim: Simulation, b: Dictionary, now: float) -> void:
	var at := Vector2(b["x"], b["z"])
	Combat._fx({"type": "skel_boom", "x": at.x, "z": at.y, "r": BLAST["r"], "age": 0.0, "duration": 0.7, "color": EMBER})
	Combat.flash(at.x, at.y, Color("#fff0d0"))
	Sfx.at("flammes_mort", at.x, at.y)
	_splash(sim, at, BLAST["r"], float(b["dmg"]) * BLAST["damage"], false, null)
	var n: int = BLAST["balls"]
	var a0 := sim.rng.randf() * TAU
	for i in n:
		var a := a0 + i * TAU / n
		EnemyShots._add({"kind": "fire", "x": at.x + cos(a) * 0.8, "z": at.y + sin(a) * 0.8, "vx": cos(a) * BLAST["ball_speed"],
			"vz": sin(a) * BLAST["ball_speed"], "r": BLAST["ball_r"], "dmg": float(b["dmg"]) * BLAST["ball_damage"], "born": now,
			"until": now + BLAST["ball_range"] / BLAST["ball_speed"], "seed": sim.rng.randi()})


## Dégâts de zone : alliés, ennemis (sauf les squelettes si `spare`), barricades.
static func _splash(sim: Simulation, at: Vector2, r: float, dmg: float, spare: bool, src: Enemy) -> void:
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and u.pos().distance_to(at) < r:
			sim.combat.hit_unit(u, dmg)
	for o: Enemy in GameState.enemies.duplicate():
		if o == src or o.hp <= 0.0 or (spare and KINDS.has(o.kind)) or o.pos().distance_to(at) >= r:
			continue
		sim.combat.damage(o, dmg)
		Combat.flash(o.x, o.z, Color("#ffb050"))
	for o: Dictionary in GameState.placed.duplicate():
		if o["item"] == "barricade" and Vector2(float(o["x"]), float(o["z"])).distance_to(at) < r + Simulation.Placeables.CELL / 2.0:
			Simulation.Placeables.hit(sim, o, dmg)
