class_name Wildlife
extends RefCounted
## Faune hostile de la jungle : crocodiles à l'affût sur les berges (souvent près des ponts) et félins sur
## leur territoire en forêt dense. Neutres : ils attaquent tout ce qui s'approche, alliés comme ennemis des
## vagues, puis regagnent leur repaire. Ce sont des Enemy (neutral = true, beast = true) : alliés et
## balistes les ciblent comme les autres ennemis ; ils ne comptent ni pour la menace ni pour la fin de vague.
## Un repaire vidé se repeuple au bout de RESPAWN_WAVES vagues. Les félins voient plus loin la nuit.

const KINDS := {
	"croc": {"hp": 160.0, "speed": 3.4, "range": 1.6, "damage": 14.0, "cd": 1.6, "armor": 4.0, "aggro": 4.0, "leash": 6.0},
	"feline": {"hp": 90.0, "speed": 4.3, "range": 1.4, "damage": 10.0, "cd": 0.9, "armor": 1.0, "aggro": 6.0, "leash": 12.0},
	# Biome 2 (Veines de vert-de-gris). Tique de filon : collée à un filon illimité, ne mord que ce qui vient le lui
	# disputer. Anguille des puits : au centre d'un bassin, immobile ; « zap » : sa décharge frappe d'un coup tout
	# ce qui se tient à portée du bassin, Exilés comme ennemis des vagues.
	"tick": {"hp": 40.0, "speed": 1.6, "range": 1.5, "damage": 5.0, "cd": 1.5, "armor": 4.0, "aggro": 4.0, "leash": 7.0},
	"eel": {"hp": 60.0, "speed": 0.0, "range": 13.5, "damage": 8.0, "cd": 3.0, "armor": 0.0, "aggro": 13.5, "leash": 20.0, "zap": true},
}
## Instant de la décharge dans l'animation d'attaque de l'anguille (elle dresse la tête, puis décharge).
const ZAP_WINDUP := 0.7
const CROCS := 10
const FELINES := 6
const RESPAWN_WAVES := 3
## Les félins repèrent leurs proies de plus loin en pleine nuit.
const NIGHT_AGGRO := 1.5


## Repaires de la partie (fonction de la graine) : {kind, x, z}.
static func lairs(state: TerrainState, map_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := state.river
	var f := state.flora
	if r == null:
		return out
	# Biome 2 : une tique devant chaque filon illimité, une anguille dans chaque bassin.
	var north := Biomes.north_z(0)
	for origin: Vector2i in state.lodes:
		var c := Vector2(origin + Vector2i.ONE) * 4.0
		if c.y < north:
			var at := state.push_out_of_rock(c + Vector2(0.0, 6.0))
			out.append({"kind": "tick", "x": at.x, "z": at.y})
	for pool: Dictionary in state.pools:
		var pc: Vector2 = pool["center"]
		if pc.y < north:
			out.append({"kind": "eel", "x": pc.x, "z": pc.y})
	var rng := Rng.new(map_seed ^ 0xc20c)
	# Crocodiles : la moitié près d'un pont, le reste le long des berges.
	var tries := 0
	var base := out.size()
	while out.size() - base < CROCS and tries < 400:
		tries += 1
		var x: float
		if out.size() - base < CROCS / 2:
			var b: Dictionary = r.bridges[floori(rng.next() * r.bridges.size())]
			x = float(b["x"]) + (1.0 if rng.next() < 0.5 else -1.0) * (River.DECK_HALF + 4.0 + rng.next() * 8.0)
		else:
			x = CaveShape.WORLD_X0 + 20.0 + rng.next() * (CaveShape.WORLD_X1 - CaveShape.WORLD_X0 - 40.0)
		var side := 1.0 if rng.next() < 0.5 else -1.0
		var z := r.center(x) + side * (r.half_width(x) + 0.4)
		if not r.bridge_near(x).is_empty() or not state.walkable(x, z) or _crowded(out, x, z, 14.0):
			continue
		out.append({"kind": "croc", "x": x, "z": z})
	# Félins : forêt dense, loin du chemin central et de la rivière.
	tries = 0
	var placed := 0
	while placed < FELINES and tries < 2000:
		tries += 1
		var x := CaveShape.WORLD_X0 + 20.0 + rng.next() * (CaveShape.WORLD_X1 - CaveShape.WORLD_X0 - 40.0)
		var z := CaveShape.mountain_edge(x) + 12.0 + rng.next() * (CaveShape.WORLD_Z1 - CaveShape.mountain_edge(x) - 20.0)
		if absf(x) < 30.0 or r.bank_distance(x, z) < 8.0 or not state.walkable(x, z) or _crowded(out, x, z, 40.0):
			continue
		if f and tries < 1500 and f.zone_at(x, z) != Flora.Zone.DENSE:
			continue
		out.append({"kind": "feline", "x": x, "z": z})
		placed += 1
	return out


static func _crowded(list: Array[Dictionary], x: float, z: float, gap: float) -> bool:
	for l in list:
		if absf(float(l["x"]) - x) < gap and absf(float(l["z"]) - z) < gap:
			return true
	return false


## Peuple les repaires au début de la partie.
static func populate(sim: Simulation, map_seed: int) -> void:
	GameState.wildlife_lairs.clear()
	for l in lairs(sim.state(), map_seed):
		l["beast"] = null
		l["empty_since"] = -1
		GameState.wildlife_lairs.append(l)
		_spawn(l)


static func _spawn(l: Dictionary) -> void:
	var k: String = l["kind"]
	var K: Dictionary = KINDS[k]
	var e := Enemy.make(k, l["x"], l["z"], 0.5)
	e.hp = K["hp"]
	e.max_hp = K["hp"]
	e.tactical_last_hp = e.hp
	e.speed = K["speed"]
	e.reach = K["range"]
	e.damage = K["damage"]
	e.armor = K["armor"]
	e.beast = true
	e.neutral = true
	e.home = Vector2(l["x"], l["z"])
	l["beast"] = e
	l["empty_since"] = -1
	GameState.enemies.append(e)


## Nouvelle vague : les repaires vides depuis RESPAWN_WAVES vagues se repeuplent.
static func on_wave(wave: int) -> void:
	for l in GameState.wildlife_lairs:
		var e: Enemy = l["beast"]
		if e != null and e.hp > 0.0:
			continue
		if int(l["empty_since"]) < 0:
			l["empty_since"] = wave
		elif wave - int(l["empty_since"]) >= RESPAWN_WAVES:
			_spawn(l)


static func aggro(e: Enemy) -> float:
	var a: float = KINDS[e.kind]["aggro"]
	if e.kind == "feline":
		a *= lerpf(1.0, NIGHT_AGGRO, DayNight.night(GameState.sim_time))
	return a


## Proie la plus proche de la bête, sur son territoire : unité visible ou ennemi des vagues.
static func prey(e: Enemy, alive: Array[Unit]) -> Unit:
	var leash: float = KINDS[e.kind]["leash"]
	var reach := aggro(e)
	var best: Unit = null
	var bd := INF
	var ex := e.x
	var ez := e.z
	for u in alive:
		# Écart sur un seul axe déjà hors de portée : la distance (≥ |dx| et ≥ |dz|) l'est aussi.
		var dx := u.x - ex
		if dx >= reach or dx <= -reach:
			continue
		var dz := u.z - ez
		if dz >= reach or dz <= -reach or u.hidden:
			continue
		var d := Combat.hyp(dx, dz)
		if d < reach and d < bd and u.pos().distance_to(e.home) < leash + reach:
			best = u
			bd = d
	for o: Enemy in GameState.enemies:
		var dx := o.x - ex
		if dx >= reach or dx <= -reach:
			continue
		var dz := o.z - ez
		if dz >= reach or dz <= -reach:
			continue
		if o == e or o.neutral or o.hp <= 0.0:
			continue
		var d := Combat.hyp(dx, dz)
		if d < reach and d < bd and o.pos().distance_to(e.home) < leash + reach:
			best = o
			bd = d
	return best


static func tick(sim: Simulation, dt: float, alive: Array[Unit]) -> void:
	for e: Enemy in GameState.enemies:
		if not e.neutral or e.hp <= 0.0:
			continue
		e.cooldown -= dt
		if e.stun > 0.0:
			e.stun -= dt
			continue
		# Une bête blessée se retourne contre son agresseur s'il est à portée de vue.
		var target: Unit = prey(e, alive)
		e.wild_target = target
		var goal := e.home if target == null else target.pos()
		var d := Combat.hyp(goal.x - e.x, goal.y - e.z)
		var limit := 0.3 if target == null else e.reach
		if d > limit:
			var spd := e.speed * (Catalog.SILLON["slow"] if e.slow_until > GameState.sim_time else 1.0) * Weather.speed_at(e.x, e.z, e.kind != "croc")
			if target == null:
				spd *= 0.5
			var next := sim.steer(e, goal)
			var dir := next - e.pos()
			if dir.length() > 0.001:
				var step := e.pos() + dir.normalized() * minf(spd * dt, dir.length())
				if sim.state().walkable(step.x, step.y):
					e.x = step.x
					e.z = step.y
				e.face = -1 if dir.x < 0.0 else 1
		# Anguille : décharge différée de ZAP_WINDUP, sur tout ce qui est à portée du bassin.
		if e.strike_at < INF and GameState.sim_time >= e.strike_at:
			e.strike_at = INF
			_zap(sim, e, alive)
		if target != null and d <= e.reach and e.cooldown <= 0.0 and KINDS[e.kind].get("zap", false):
			e.attack_started = GameState.sim_time
			e.face = -1 if target.x < e.x else 1
			e.strike_at = GameState.sim_time + ZAP_WINDUP
			e.cooldown = KINDS[e.kind]["cd"]
		elif target != null and d <= e.reach and e.cooldown <= 0.0:
			e.attack_started = GameState.sim_time
			e.face = -1 if target.x < e.x else 1
			sim.combat.damage(target, Combat.after_armor(target, e.damage))
			Combat.flash(target.x, target.z, Color("#c86a4a"))
			Sfx.at("croc" if e.kind == "croc" else "felin", e.x, e.z)
			e.cooldown = KINDS[e.kind]["cd"]


static func _zap(sim: Simulation, e: Enemy, alive: Array[Unit]) -> void:
	var hit := false
	for u: Unit in alive:
		if not u.hidden and Combat.hyp(u.x - e.x, u.z - e.z) <= e.reach:
			sim.combat.damage(u, Combat.after_armor(u, e.damage))
			Combat.flash(u.x, u.z, Color("#c0dcff"))
			hit = true
	for o: Enemy in GameState.enemies.duplicate():
		if o != e and not o.neutral and o.hp > 0.0 and Combat.hyp(o.x - e.x, o.z - e.z) <= e.reach:
			sim.combat.damage(o, e.damage)
			Combat.flash(o.x, o.z, Color("#c0dcff"))
			hit = true
	Combat.zone(e.x, e.z, e.reach, Color("#6a9aff"))
	if hit:
		Sfx.at("bouclier_dore", e.x, e.z)


## Bête neutre qui attaque cet ennemi des vagues (pour qu'il riposte), ou null.
static func attacker_of(o: Enemy) -> Enemy:
	for e: Enemy in GameState.enemies:
		if e.neutral and e.hp > 0.0 and e.wild_target == o:
			return e
	return null
