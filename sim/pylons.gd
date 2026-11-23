class_name Pylons
extends RefCounted
## Pylônes de Merenor (planches/pylone-merenor-v2-propositions.html : Obélisque suintant, Nappe débordante,
## Mousse veinée). Ils remplacent les portails maléfiques des galeries : placés par anneaux de chemin depuis
## l'Ancre (TerrainState._place_pylons, galeries reliées du 2026-11-22), éveillés quand un allié les voit
## (Awaken), posés sur 2 × 2 cases infranchissables (TerrainState.pylon_cells).
##
## - Indestructible. Une meute de 4 à 6 bêtes, dont un alpha (PV et dégâts × ALPHA), garde la nappe.
##   Sans intrus, elle patrouille : ronde en file autour du socle, alpha en tête, coupée de haltes (_patrol).
## - Une bête tuée renaît à sa place au bout de RESPAWN secondes (minuteur au-dessus du pylône).
## - Canalisé si et seulement si un esprit de CHAQUE dieu prie autour (job "pray_pylon") : plus aucune
##   renaissance, la nappe se retire (cover → 0). Dès qu'il manque un culte, le cycle reprend : chaque place
##   vide repart pour RESPAWN secondes et la nappe revient.
## - La nappe retire CORRUPTION_DPS PV par seconde à l'Ingénieur ; les adeptes y sont immunisés.
## - Bénédiction : l'Ingénieur incarné, collé au socle, appuie sur E (toggle_bless) et prie sur place
##   (job "bless_pylon") ; il y amasse BLESS_RATE seconde de
##   répit par seconde de prière. Quand il cesse, le répit s'écoule et gèle toutes les renaissances en cours
##   (chaque seconde de prière retarde d'autant l'apparition des monstres) ; minuteur au-dessus du pylône.
##   BLESS_CHANNEL secondes de prière d'affilée canalisent aussi le pylône, pour de bon (p["sealed"]) : il reste
##   canalisé sans prière ni esprits ; la prière cesse d'elle-même.
##
## Les pylônes sont les dictionnaires de TerrainState.portals (id, x, z, active, threat) ; l'état de jeu y est
## ajouté au premier tick (slots, cover, praying…) et disparaît avec eux à la nouvelle partie.

const RESPAWN := 60.0
const PACK_MIN := 4
const PACK_MAX := 6
const ALPHA := 2.0
const CORRUPTION_DPS := 1.0
## Secondes de répit gagnées par seconde de prière de l'Ingénieur.
const BLESS_RATE := 1.0
## Secondes de prière d'affilée de l'Ingénieur qui canalisent le pylône pour de bon.
const BLESS_CHANNEL := 10.0
## Place de l'Ingénieur qui bénit sans place donnée : devant le socle, au sud.
const BLESS_SPOT := Vector2(0.0, 6.5)
## Distance au socle (unités) à laquelle l'Ingénieur le touche et peut le bénir avec E.
const CONTACT := 1.4
## Temps de retrait (ou de retour) complet de la nappe.
const COVER_TIME := 2.5
## Anneau des coins de prière (unités du centre), vers lesquels les esprits marchent avant d'être à portée.
const PRAY_RING := 6.2
## Un esprit canalise dès qu'il est à 3 cases (12 unités) du socle ou moins.
const CHANNEL_REACH := 12.0
## Garde de la meute : distance de repérage, laisse autour du pylône.
const AGGRO := 14.0
const LEASH := 15.0
## Ronde de la meute autour du socle, en file derrière l'alpha : rayon de la piste, écart entre deux bêtes
## (radians), allure (unités/s), durée d'une marche et d'une halte (secondes, tirées dans l'intervalle).
const PATROL_R := 9.5
const PATROL_GAP := 0.44
const PATROL_SPEED := 2.6
const PATROL_MARCH := Vector2(9.0, 16.0)
const PATROL_HALT := Vector2(2.0, 4.5)
## Forme de la nappe (unités de monde, planche ×1/8) : rayon de base, lobes, bruit local, flaques.
## Lobes doux (R entre ≈ 10 et 19 u) : la nappe entoure tout le pylône, bord irrégulier sans branches en étoile.
const BASE_R := 14.5
const LOBE := 3.0
const LOBE_FINE := 1.5
const LOC := 3.25
const SATELLITES := 9
const RETREAT := 26.0
## Demi-côté (unités) de la zone dessinée autour du centre.
const EXTENT := 32.0
const LOBE_SAMPLES := 256
const CULTS: Array[String] = ["aether", "indra", "medeina", "sigil"]
## Ordre des rainures du socle (pylon_sides.png) : NO, NE, SE, SO.
## Places de prière de la planche validée (v2, SPOT) ramenées dans la salle : un esprit par diagonale,
## Aether au nord-ouest, Indra au nord-est, Medeina au sud-est, Sigil au sud-ouest (≈ 2 cases du socle).
const CORNER := {"aether": Vector2(-10, -9), "indra": Vector2(10, -9), "medeina": Vector2(10, 10.5), "sigil": Vector2(-10, 10.5)}
## Rayon de prière : de la poitrine de l'esprit (px natifs au-dessus des pieds) au foyer de l'obélisque.
const BEAM_FROM := 15.0
const FOCUS := 89.0


# ---------------------------------------------------------------- Forme de la nappe

## Bruits et lobes du pylône (mis en cache dans p["zone"]).
static func zone(p: Dictionary) -> Dictionary:
	if p.has("zone"):
		return p["zone"]
	# Graine tirée de la position : la vue (PylonZone) et la simulation voient la même nappe.
	var seed := (roundi(float(p["x"])) * 73856093) ^ (roundi(float(p["z"])) * 19349663) ^ (int(p["id"]) * 83492791)
	var loc := FastNoiseLite.new()
	loc.noise_type = FastNoiseLite.TYPE_SIMPLEX
	loc.seed = seed
	loc.frequency = 0.45
	loc.fractal_type = FastNoiseLite.FRACTAL_FBM
	loc.fractal_octaves = 3
	var lobes := FastNoiseLite.new()
	lobes.noise_type = FastNoiseLite.TYPE_SIMPLEX
	lobes.seed = seed + 1
	lobes.frequency = 1.0
	lobes.fractal_type = FastNoiseLite.FRACTAL_NONE
	var table := PackedFloat32Array()
	table.resize(LOBE_SAMPLES)
	for k in LOBE_SAMPLES:
		var a := float(k) / LOBE_SAMPLES * TAU
		var l1 := clampf(lobes.get_noise_2d(cos(a) * 1.6 + 3.0, sin(a) * 1.6 + 3.0) * 1.5, -1.0, 1.0)
		var l1b := clampf(lobes.get_noise_2d(cos(a) * 3.2 + 41.0, sin(a) * 3.2 + 41.0) * 1.4, -1.0, 1.0)
		table[k] = BASE_R + LOBE * l1 + LOBE_FINE * l1b
	var rng := Rng.new(seed + 2)
	var sats: Array[Vector3] = []
	for k in SATELLITES:
		var a := rng.next() * TAU
		var r0 := _lobe(table, a)
		var dist := r0 + 1.75 + rng.next() * 3.5
		sats.append(Vector3(cos(a) * dist, sin(a) * dist / 1.12, 0.5 + rng.next() * 0.875))
	var z := {"loc": loc, "table": table, "sats": sats}
	p["zone"] = z
	return z


static func _lobe(table: PackedFloat32Array, a: float) -> float:
	var f := fposmod(a, TAU) / TAU * LOBE_SAMPLES
	var i := floori(f)
	return lerpf(table[i % LOBE_SAMPLES], table[(i + 1) % LOBE_SAMPLES], f - i)


## Bruit local de bord, dans [-0,5 ; 0,5] (comme fbm − 0,5 sur la planche).
static func local_noise(p: Dictionary, x: float, z: float) -> float:
	return clampf((zone(p)["loc"] as FastNoiseLite).get_noise_2d(x, z) * 0.7, -0.5, 0.5)


## Distance au bord de la nappe pleine (> 0 dedans), sans retrait ni masque de sol.
static func edge(p: Dictionary, x: float, z: float) -> float:
	var Z := zone(p)
	var dx := x - float(p["x"])
	var dz := (z - float(p["z"])) * 1.12
	var d := sqrt(dx * dx + dz * dz)
	var loc := local_noise(p, x, z)
	var e := _lobe(Z["table"], atan2(dz, dx)) + LOC * loc - d
	for s: Vector3 in Z["sats"]:
		e = maxf(e, s.z + 0.75 * loc - Vector2(x - float(p["x"]) - s.x, z - float(p["z"]) - s.y).length())
	return minf(e, float(p.get("cover", 1.0)) * RETREAT - (d + 2.25 * loc))


## Le point est dans la nappe d'un pylône éveillé (sol découvert, hors du socle).
static func corrupted(state: TerrainState, x: float, z: float) -> bool:
	for p: Dictionary in state.portals:
		if not p["active"] or float(p.get("cover", 1.0)) <= 0.0:
			continue
		if absf(x - float(p["x"])) > EXTENT or absf(z - float(p["z"])) > EXTENT:
			continue
		if edge(p, x, z) > 0.0 and state.ground(x, z):
			return true
	return false


# ---------------------------------------------------------------- Simulation

static func tick(sim: Simulation, dt: float) -> void:
	if GameState.ended:
		return
	var st := sim.state()
	for p: Dictionary in st.portals:
		if not p["active"]:
			continue
		if not p.has("slots"):
			_wake(sim, p)
		var cults := praying_cults(p)
		var was: bool = p["channeled"]
		# Prière de l'Ingénieur : BLESS_CHANNEL secondes d'affilée scellent la canalisation.
		var now_blessed := blessed(p)
		if now_blessed and not was and not p.get("sealed", false):
			p["bless_run"] = float(p.get("bless_run", 0.0)) + dt
			if p["bless_run"] >= BLESS_CHANNEL:
				p["sealed"] = true
				for u in GameState.units:
					if u.role == "engineer" and u.job != null and u.job.get("type") == "bless_pylon" and u.job.get("pylon") == p:
						sim.cancel_work(u)
				now_blessed = false
		else:
			p["bless_run"] = 0.0
		p["channeled"] = p.get("sealed", false) or cults.size() == CULTS.size()
		p["praying"] = cults
		if was and not p["channeled"]:
			# Le cycle d'invocation reprend : chaque place vide repart pour une minute.
			for s: Dictionary in p["slots"]:
				if s["enemy"] == null:
					s["dead_at"] = GameState.sim_time
			sim.say("Un esprit a quitté le Pylône de Merenor : la corruption revient et ses gardiens renaîtront.", 3.5)
		elif p["channeled"] and not was:
			sim.say("Pylône de Merenor canalisé : la corruption se retire, plus aucun gardien n'en renaîtra.", 3.5)
			Combat.zone(p["x"], p["z"], 6.0, Color("#ece8dc"))
		# Bénédiction : amassée pendant la prière, elle s'écoule ensuite et gèle les renaissances.
		var blessing := float(p.get("blessing", 0.0))
		p["blessing_now"] = now_blessed
		if p["blessing_now"]:
			blessing += dt * BLESS_RATE
		elif blessing > 0.0:
			var used := minf(dt, blessing)
			blessing -= used
			for s: Dictionary in p["slots"]:
				if s["enemy"] == null:
					s["dead_at"] = float(s["dead_at"]) + used
		p["blessing"] = blessing
		# Reflux (PortalNet) : la nappe ressort pendant l'annonce et couvre la salle pendant la sortie.
		var target := PortalNet.reflux_k(p) if p["channeled"] else 1.0
		p["cover"] = move_toward(float(p["cover"]), target, dt / COVER_TIME)
		_patrol(p, dt)
		for s: Dictionary in p["slots"]:
			var e: Enemy = s["enemy"]
			if e != null and e.hp <= 0.0:
				s["enemy"] = null
				s["dead_at"] = GameState.sim_time
			if s["enemy"] == null and not p["channeled"] and GameState.sim_time - float(s["dead_at"]) >= RESPAWN:
				_spawn(sim, p, s)
	_corrode(sim, dt)


## Éveil : la meute apparaît d'un coup (4 à 6 places, la dernière est l'alpha).
static func _wake(sim: Simulation, p: Dictionary) -> void:
	p["cover"] = 1.0
	p["channeled"] = false
	p["praying"] = []
	var rng := Rng.new(sim.state().seed + int(p["id"]) * 31 + 5)
	var n := PACK_MIN + floori(rng.next() * (PACK_MAX - PACK_MIN + 1))
	var slots: Array[Dictionary] = []
	for k in n:
		var home := _slot_spot(sim.state(), p, rng, k, n)
		# Rang dans la file de la ronde : l'alpha en tête.
		slots.append({"x": home.x, "z": home.y, "alpha": k == n - 1, "rank": (k + 1) % n, "enemy": null, "dead_at": -INF})
	p["slots"] = slots
	p["round"] = rng.next() * TAU
	p["round_dir"] = 1.0 if rng.next() < 0.5 else -1.0
	p["round_rng"] = rng
	p["halted"] = false
	p["round_until"] = GameState.sim_time + lerpf(PATROL_MARCH.x, PATROL_MARCH.y, rng.next())
	for s in slots:
		_spawn(sim, p, s)


## Place d'une bête : dans la nappe, sur du sol praticable, en couronne autour du socle.
static func _slot_spot(st: TerrainState, p: Dictionary, rng: Rng, k: int, n: int) -> Vector2:
	var c := Vector2(p["x"], p["z"])
	for t in 60:
		var a := (float(k) + rng.next() * 0.8) / n * TAU
		var r := 6.0 + rng.next() * 6.0
		var q := c + Vector2(cos(a), sin(a)) * r
		if st.walkable(q.x, q.y) and edge(p, q.x, q.y) > 1.0:
			return q
	return st.push_out_of_rock(c + Vector2(0, 6))


static func _spawn(sim: Simulation, p: Dictionary, s: Dictionary) -> void:
	var tier := Catalog.menace_tier(GameState.menace) + Biomes.threat_tiers(int(p.get("threat", 1)))
	var e := Enemy.make("beast", s["x"], s["z"], 0.6, Catalog.menace_stats(tier, true))
	if s["alpha"]:
		e.alpha = true
		e.hp *= ALPHA
		e.max_hp = e.hp
		e.tactical_last_hp = e.hp
		e.damage *= ALPHA
		e.name = "Alpha de Merenor"
	e.pylon = p
	e.home = Vector2(s["x"], s["z"])
	e.memo["rank"] = int(s["rank"])
	e.risen_at = GameState.sim_time
	s["enemy"] = e
	s["dead_at"] = -INF
	GameState.enemies.append(e)
	Sfx.at("aberration", e.x, e.z)


## Ronde de la meute : la tête de file tourne autour du socle, avec des haltes.
static func _patrol(p: Dictionary, dt: float) -> void:
	if GameState.sim_time >= float(p["round_until"]):
		var rng: Rng = p["round_rng"]
		p["halted"] = not p["halted"]
		var span: Vector2 = PATROL_HALT if p["halted"] else PATROL_MARCH
		p["round_until"] = GameState.sim_time + lerpf(span.x, span.y, rng.next())
	if not p["halted"]:
		p["round"] = fposmod(float(p["round"]) + float(p["round_dir"]) * PATROL_SPEED / PATROL_R * dt, TAU)


## Place d'un gardien dans la ronde : sur la piste, à son rang derrière la tête, sur deux files décalées.
static func patrol_spot(st: TerrainState, p: Dictionary, e: Enemy) -> Vector2:
	var rank := int(e.memo.get("rank", 0))
	var a := float(p["round"]) - float(p["round_dir"]) * rank * PATROL_GAP
	var r := PATROL_R + (0.0 if rank == 0 else 1.5 if rank % 2 == 1 else -1.2)
	var q := Vector2(float(p["x"]) + cos(a) * r, float(p["z"]) + sin(a) * r / 1.12)
	if not st.walkable(q.x, q.y):
		q = st.push_out_of_rock(q)
	return q if st.walkable(q.x, q.y) else e.home


## Cultes des esprits qui prient en ce moment au pylône (sur place).
static func praying_cults(p: Dictionary) -> Array:
	var out := []
	for u in GameState.units:
		if not u.alive() or u.hidden or not u.working or u.job == null or u.job.get("type") != "pray_pylon" or u.job.get("pylon") != p:
			continue
		if CULTS.has(u.role) and not out.has(u.role):
			out.append(u.role)
	return out


## L'Ingénieur prie devant ce pylône en ce moment (sur place).
static func blessed(p: Dictionary) -> bool:
	for u in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden and u.working and u.job != null \
				and u.job.get("type") == "bless_pylon" and u.job.get("pylon") == p:
			return true
	return false


## Minuteur de la prochaine renaissance : {rem, progress, waiting} ou vide.
static func timer(p: Dictionary) -> Dictionary:
	if not p.has("slots") or p["channeled"]:
		return {}
	var best := INF
	var n := 0
	for s: Dictionary in p["slots"]:
		if s["enemy"] == null:
			n += 1
			best = minf(best, RESPAWN - (GameState.sim_time - float(s["dead_at"])))
	if n == 0:
		return {}
	best = clampf(best, 0.0, RESPAWN)
	return {"rem": best, "progress": 1.0 - best / RESPAWN, "waiting": n - 1}


## La corruption ronge l'Ingénieur (un point de vie à chaque seconde passée dans la nappe).
static func _corrode(sim: Simulation, dt: float) -> void:
	for u in GameState.units:
		if u.role != "engineer" or not u.alive() or u.hidden:
			continue
		if not corrupted(sim.state(), u.x, u.z):
			u.memo.erase("corruption")
			continue
		var acc: float = u.memo.get("corruption", 0.0) + dt * CORRUPTION_DPS
		while acc >= 1.0:
			acc -= 1.0
			sim.combat.damage(u, 1.0)
		u.memo["corruption"] = acc


## Gardien de la meute : attaque ce qui entre sur son territoire, puis reprend sa ronde autour du pylône.
static func act(sim: Simulation, e: Enemy, dt: float, alive: Array[Unit]) -> void:
	e.cooldown -= dt
	if e.stun > 0.0:
		e.stun -= dt
		return
	# Chien du reflux : il sort du seuil en silhouette (UnitView, 1,4 s) avant d'agir.
	if e.memo.get("reflux", false) and GameState.sim_time < e.risen_at + 1.4:
		return
	var p: Dictionary = e.pylon
	var center := Vector2(p["x"], p["z"])
	var target: Unit = null
	var bd := INF
	var ex := e.x
	var ez := e.z
	var sight := Catalog.BEAST_SIGHT if e.kind == "beast" else AGGRO
	# Laisse d'un chien : comptée depuis sa ronde (PATROL_R du socle), pas depuis le socle, sinon quiconque
	# passe devant lui côté extérieur (à plus de LEASH du socle) n'est jamais repéré.
	var leash := PATROL_R + sight if e.kind == "beast" else LEASH
	for u in alive:
		# Écart sur un seul axe déjà hors de vue : la distance (≥ |dx| et ≥ |dz|) l'est aussi.
		var dx := u.x - ex
		if dx >= sight or dx <= -sight:
			continue
		var dz := u.z - ez
		if dz >= sight or dz <= -sight or u.hidden:
			continue
		var d := Combat.hyp(dx, dz)
		if d < sight and d < bd and u.pos().distance_to(center) < leash:
			target = u
			bd = d
	# Chien du reflux (PortalNet) : il vise d'abord les esprits qui prient au pylône.
	if e.memo.get("reflux", false):
		var sp := PortalNet.spirit_target(p, e)
		if sp != null and (target == null or Pylons.CULTS.has(sp.role)):
			target = sp
	# Frappé de loin (tireur hors de la laisse) : il riposte quand même s'il le voit.
	if target == null and e.hp < e.max_hp and e.memo.has("hurt_by"):
		var src: Unit = e.memo["hurt_by"]
		if src != null and src.alive() and src.pos().distance_to(center) < leash + AGGRO:
			target = src
	var goal := patrol_spot(sim.state(), p, e) if target == null else target.pos()
	var dist := Combat.hyp(goal.x - e.x, goal.y - e.z)
	# En marche, il colle à sa place qui avance (sans à-coups) ; à la halte, il s'arrête dès qu'il y est.
	var limit := e.reach if target != null else 0.3 if p["halted"] else 0.02
	# Chien de la Bête : il ne fait que cracher (comme dans Combat.update_enemies), arrêté à distance de tir, ou plus
	# près tant qu'un mur lui cache sa cible.
	var spits := e.kind == "beast"
	if target != null and spits:
		EnemyShots.spit(sim, e, target, target.pos(), dist)
		limit = Catalog.BEAST_STANDOFF if dist > Catalog.BEAST_STANDOFF or sim.combat.clear_shot(e.pos(), target.pos()) else Combat.MELEE_REACH
	if dist > limit:
		var spd := e.speed * (Catalog.SILLON["slow"] if e.slow_until > GameState.sim_time else 1.0) * Weather.speed_at(e.x, e.z)
		if target == null:
			spd *= 0.6
		var next := sim.steer(e, goal)
		var dir := next - e.pos()
		if dir.length() > 0.001:
			var step := e.pos() + dir.normalized() * minf(spd * dt, dir.length())
			if sim.state().walkable(step.x, step.y):
				e.x = step.x
				e.z = step.y
			e.face = -1 if dir.x < 0.0 else 1
	if target != null and not spits and dist <= e.reach and e.cooldown <= 0.0:
		e.attack_started = GameState.sim_time
		e.face = -1 if target.x < e.x else 1
		var dmg := e.damage
		if target.shield > 0.0:
			dmg *= 0.35
		sim.combat.damage(target, Combat.after_armor(target, dmg))
		Combat.flash(target.x, target.z, Color("#e17b63"))
		Sfx.at("aberration", e.x, e.z)
		e.cooldown = Catalog.ENEMY[e.kind]["cd"]


# ---------------------------------------------------------------- Prière

## Pylône éveillé sous ce point (socle de 2 × 2 cases), ou vide.
static func at(state: TerrainState, p: Vector2) -> Dictionary:
	for q: Dictionary in state.portals:
		if q["active"] and absf(p.x - float(q["x"])) <= 4.5 and absf(p.y - float(q["z"]) + 1.5) <= 6.0:
			return q
	return {}


## Distance (unités) du point au socle de 2 × 2 cases du pylône (0 dessus).
static func socle_distance(p: Dictionary, at: Vector2) -> float:
	var r := Rect2(float(p["x"]) - 4.0, float(p["z"]) - 4.0, 8.0, 8.0)
	return at.clamp(r.position, r.end).distance_to(at)


## Pylône éveillé dont le socle (2 × 2 cases) est au contact du point, ou vide.
static func touching(state: TerrainState, at: Vector2) -> Dictionary:
	for p: Dictionary in state.portals:
		if not p["active"]:
			continue
		if socle_distance(p, at) <= CONTACT:
			return p
	return {}


## Touche E : l'Exilé incarné (l'Ingénieur) collé au socle d'un pylône commence à le bénir sur place, ou
## arrête s'il le bénissait déjà. Faux si rien à faire (la touche sert alors à la capsule).
static func toggle_bless(sim: Simulation) -> bool:
	var eng := GameState.incarnated
	if eng == null or eng.role != "engineer" or not eng.alive() or eng.hidden:
		return false
	if eng.job != null and eng.job.get("type") == "bless_pylon":
		sim.cancel_work(eng)
		return true
	var p := touching(sim.state(), eng.pos())
	if p.is_empty():
		return false
	sim.set_job(eng, {"type": "bless_pylon", "pylon": p, "spot": eng.pos()})
	sim.say("L’Ingénieur bénit le Pylône de Merenor : chaque seconde de prière retarde d’autant le retour des monstres, dix d’affilée le canalisent. E pour arrêter.", 3.5)
	return true


## Place de l'Ingénieur qui bénit le pylône (sa place à l'appui sur E, sinon devant le socle).
static func bless_spot(state: TerrainState, p: Dictionary, job: Dictionary = {}) -> Vector2:
	if job.has("spot"):
		return job["spot"]
	var spot := Vector2(p["x"], p["z"]) + BLESS_SPOT
	if not state.walkable(spot.x, spot.y):
		spot = state.push_out_of_rock(spot)
	return spot


## Place de prière d'un esprit : son coin (selon son culte), les suivants du même culte à côté.
static func prayer_spot(state: TerrainState, u: Unit, p: Dictionary) -> Vector2:
	var same := GameState.units.filter(func(o: Unit) -> bool:
		return o.alive() and o.job != null and o.job.get("type") == "pray_pylon" and o.job.get("pylon") == p and o.role == u.role)
	var i := maxi(0, same.find(u))
	var corner: Vector2 = CORNER.get(u.role, Vector2(0, PRAY_RING))
	var c := Vector2(p["x"], p["z"])
	var spot := c + corner + corner.normalized() * (i * 1.3)
	if not state.walkable(spot.x, spot.y):
		spot = state.push_out_of_rock(spot)
	return spot
