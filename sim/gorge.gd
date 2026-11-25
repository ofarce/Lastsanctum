class_name Gorge
extends RefCounted
## Gorge-Cuivre, la Dévoreuse de filons : boss de fin du biome 2 (Veines de vert-de-gris), modèle 3 « Le Mille-pattes
## mineur » de planches/biomes-monstres-finaux.html. Elle dort sous sa salle (TerrainState.gorge_room, rayon ROOM) et
## s'éveille quand une unité y entre. Tout le monde peut la blesser ; son armure (anneaux) vaut Catalog.ENEMY["gorge"],
## et les dégâts sont doublés tant que sa gueule est ouverte (MOUTH_MULT).
##
## Trois phases, aux deux tiers et au tiers de ses PV :
##  I   La faim : Percée et Pluie de minerai en alternance.
##  II  Le sillon : en y entrant elle laboure la salle d'un bord à l'autre (une fois) et une escouade de Byrsa arrive
##      par la brèche ; puis Percée et Pluie, plus vite.
##  III La gueule ouverte : elle reste dressée, gueule exposée, ne fait plus que pleuvoir le minerai et appelle des
##      tiques à chaque Pluie.
## Percée : elle s'enfonce, la butte file sous le sol vers une unité, un cercle l'annonce, elle rejaillit (dégâts
## dans le cercle) et reste gueule ouverte. Pluie : elle se cabre gueule ouverte, des cercles marquent les points de
## chute, les blocs tombent ; certains laissent du cuivre au sol.
## État : GameState.gorge = {state, seed, e, mode, t0, until, phase, next, marks, furrow, furrow_done, from, to, alone}.
## Rendu : world/gorge/gorge_view.gd.

const ItemStorage := preload("res://sim/item_storage.gd")

const KIND := "gorge"
const ROOM := 24.0
const BODY := {"half_w": 2.6, "top": 6.6, "foot": 1.0, "melee": 1.6}
const MOUTH_MULT := 2.0
const PHASE_HP := [2.0 / 3.0, 1.0 / 3.0]
const PHASE_NAMES := ["I · La faim", "II · Le sillon", "III · La gueule ouverte"]
## Repos entre deux attaques, par phase (s).
const REST := [1.8, 1.3, 1.0]
const PIERCE := {"sink": 0.7, "travel": 1.3, "warn": 0.9, "emerge": 0.7, "radius": 4.5, "damage": 30.0, "open": 2.2}
const RAIN := {"rear": 0.7, "hold": 2.8, "count": [7, 9, 11], "first": 1.0, "spread": 1.2, "radius": 2.6, "damage": 18.0, "ore": 0.3, "reach": 9.0}
const FURROW := {"sink": 0.7, "warn": 1.2, "run": 1.0, "width": 3.2, "damage": 40.0}
const FURROW_SQUAD := ["scout", "soldier", "shield", "archer"]
const CALL_TICKS := 3
## Sans personne dans la salle pendant ce délai, elle se rendort (sans regagner ses PV).
const FORGET := 8.0

const QUOTE_WAKE := "Le sol tremble sous la grande salle… quelque chose a mangé tous les filons d’ici."
const QUOTE_DONE := "La Gorge-Cuivre ne bouge plus. Ce qu’elle a avalé de cuivre est à nous."


static func run() -> Dictionary:
	return GameState.gorge


static func boss() -> Enemy:
	return GameState.gorge.get("e")


## En combat : éveillée et vivante (barre de boss).
static func active() -> bool:
	var e := boss()
	return e != null and e.hp > 0.0 and String(GameState.gorge.get("mode", "sleep")) != "sleep"


static func center() -> Vector2:
	return GameState.gorge.get("center", Vector2.ZERO)


static func phase_of(e: Enemy) -> int:
	var f := e.hp / maxf(1.0, e.max_hp)
	return 2 if f <= PHASE_HP[1] else 1 if f <= PHASE_HP[0] else 0


static func mouth_open() -> bool:
	var r := run()
	return String(r.get("mode", "")) in ["open", "rear", "rain"] or (int(r.get("phase", 0)) == 2 and String(r.get("mode", "")) == "idle")


## Dégâts reçus : doublés dans la gueule ouverte.
static func damage_mult() -> float:
	return MOUTH_MULT if mouth_open() else 1.0


static func tick(sim: Simulation) -> void:
	if GameState.ended or sim.world == null:
		return
	var st := sim.state()
	if st == null or st.gorge_room == null:
		return
	var r := GameState.gorge
	if r.get("state") != st or r.get("seed") != st.seed:
		r.clear()
		r["state"] = st
		r["seed"] = st.seed
		r["center"] = st.gorge_room
		r["mode"] = "sleep"
		r["phase"] = 0
		r["marks"] = []
		r["next"] = "pierce"
		r["furrow_done"] = false
		r["alone"] = 0.0
		var c: Vector2 = st.gorge_room
		var e := Enemy.make(KIND, c.x, c.y, 0.0)
		e.beast = true
		e.hidden = true
		r["e"] = e
		GameState.enemies.append(e)
	var boss := boss()
	if boss != null and boss.hp <= 0.0 and String(r["mode"]) != "dead":
		r["mode"] = "dead"
		(r["marks"] as Array).clear()
		r.erase("furrow")


static func _in_room(p: Vector2, grow := 0.0) -> bool:
	return p.distance_to(center()) <= ROOM + grow


static func _target(e: Enemy, alive: Array[Unit]) -> Unit:
	var best: Unit = null
	var bd := INF
	for u: Unit in alive:
		if u.hidden or not _in_room(u.pos(), 4.0):
			continue
		var d := u.pos().distance_to(e.pos())
		if d < bd:
			bd = d
			best = u
	return best


static func _go(r: Dictionary, mode: String, seconds: float) -> void:
	r["mode"] = mode
	r["t0"] = GameState.sim_time
	r["until"] = GameState.sim_time + seconds


## Conduite du boss, appelée par Combat.update_enemies à la place de la conduite normale.
static func act(sim: Simulation, e: Enemy, dt: float, alive: Array[Unit]) -> void:
	var r := run()
	if r.is_empty() or r.get("e") != e:
		return
	var now := GameState.sim_time
	var mode: String = r["mode"]
	_land_marks(sim, r, alive, now)
	var target := _target(e, alive)
	if mode == "sleep":
		if target != null:
			e.hidden = false
			_go(r, "emerge", PIERCE["emerge"])
			r["alone"] = 0.0
			sim.say(QUOTE_WAKE, 5.0)
			Sfx.at("vague", e.x, e.z)
		return
	# Plus personne : elle finit son geste, puis se rendort.
	r["alone"] = 0.0 if target != null else float(r["alone"]) + dt
	if target != null and absf(target.x - e.x) > 0.5 and not e.hidden:
		e.face = -1 if target.x < e.x else 1
	if now < float(r.get("until", 0.0)):
		if mode == "travel" or mode == "furrow_run":
			var k := clampf((now - float(r["t0"])) / maxf(0.01, float(r["until"]) - float(r["t0"])), 0.0, 1.0)
			var p := (r["from"] as Vector2).lerp(r["to"], k)
			if mode == "furrow_run":
				_furrow_hits(sim, r, e.pos(), p, alive)
			e.x = p.x
			e.z = p.y
		return
	var phase := phase_of(e)
	r["phase"] = phase
	match mode:
		"emerge", "open", "rain":
			_go(r, "idle", REST[phase])
		"idle":
			if float(r["alone"]) > FORGET:
				_go(r, "sink_sleep", PIERCE["sink"])
			elif target == null:
				_go(r, "idle", 0.5)
			elif phase >= 1 and not r["furrow_done"]:
				r["furrow_done"] = true
				_start_furrow(sim, r, e, target)
			elif phase == 2 or String(r["next"]) == "rain":
				r["next"] = "pierce"
				_go(r, "rear", RAIN["rear"])
			else:
				r["next"] = "rain"
				r["dest"] = _clamp_room(target.pos())
				_go(r, "sink", PIERCE["sink"])
		"sink_sleep":
			e.hidden = true
			r["mode"] = "sleep"
		"sink":
			e.hidden = true
			r["from"] = e.pos()
			r["to"] = r["dest"]
			_go(r, "travel", PIERCE["travel"])
		"travel":
			e.x = (r["to"] as Vector2).x
			e.z = (r["to"] as Vector2).y
			(r["marks"] as Array).append({"kind": "pierce", "x": e.x, "z": e.z, "r": PIERCE["radius"], "from": now, "at": now + float(PIERCE["warn"])})
			_go(r, "warn", PIERCE["warn"])
		"warn":
			e.hidden = false
			_go(r, "emerge_open", PIERCE["emerge"])
		"emerge_open":
			_go(r, "open", PIERCE["open"])
		"rear":
			_start_rain(sim, r, e, alive, phase)
			_go(r, "rain", RAIN["hold"])
		"furrow_sink":
			e.hidden = true
			_go(r, "furrow_warn", FURROW["warn"])
		"furrow_warn":
			r["from"] = (r["furrow"] as Dictionary)["a"]
			r["to"] = (r["furrow"] as Dictionary)["b"]
			e.x = (r["from"] as Vector2).x
			e.z = (r["from"] as Vector2).y
			(r["furrow"] as Dictionary)["hit"] = []
			_go(r, "furrow_run", FURROW["run"])
			Sfx.at("vague", e.x, e.z)
		"furrow_run":
			e.x = (r["to"] as Vector2).x
			e.z = (r["to"] as Vector2).y
			e.hidden = false
			_squad(sim, (r["furrow"] as Dictionary)["a"])
			r.erase("furrow")
			_go(r, "emerge_open", PIERCE["emerge"])


static func _clamp_room(p: Vector2) -> Vector2:
	var c := center()
	var d := p - c
	return c + d.limit_length(ROOM - 4.0)


## Marques au sol arrivées à terme : la Percée frappe son cercle, un bloc de la Pluie frappe le sien.
static func _land_marks(sim: Simulation, r: Dictionary, alive: Array[Unit], now: float) -> void:
	var marks: Array = r["marks"]
	for i in range(marks.size() - 1, -1, -1):
		var m: Dictionary = marks[i]
		if now < float(m["at"]):
			continue
		marks.remove_at(i)
		var at := Vector2(m["x"], m["z"])
		var dmg: float = PIERCE["damage"] if m["kind"] == "pierce" else RAIN["damage"]
		for u: Unit in alive:
			if not u.hidden and u.pos().distance_to(at) <= float(m["r"]):
				sim.combat.damage(u, Combat.boss_shot(at.y) if u.role == "engineer" else Combat.after_armor(u, dmg * Biomes.power_at(at.y)))
				Combat.flash(u.x, u.z, Color("#f0b088"))
		Combat.zone(at.x, at.y, float(m["r"]), Color("#c47b58"))
		Sfx.at("objet_pose", at.x, at.y)
		if m["kind"] == "rain" and bool(m.get("ore", false)) and sim.state().walkable(at.x, at.y):
			GameState.ground_items.append(ItemStorage.drop_of("copper", at))


static func _start_rain(sim: Simulation, r: Dictionary, e: Enemy, alive: Array[Unit], phase: int) -> void:
	var now := GameState.sim_time
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.state().seed, roundi(now * 10.0), roundi(e.hp)])
	var targets: Array[Vector2] = []
	for u: Unit in alive:
		if not u.hidden and _in_room(u.pos(), 4.0):
			targets.append(u.pos())
	if targets.is_empty():
		targets.append(center())
	var n: int = RAIN["count"][phase]
	for i in n:
		# Un bloc sur deux vise une unité ; les autres tombent autour.
		var base: Vector2 = targets[i % targets.size()]
		var off := Vector2.ZERO if i < targets.size() else Vector2.from_angle(rng.randf() * TAU) * (2.0 + rng.randf() * float(RAIN["reach"]))
		var p := _clamp_room(base + off)
		var at := now + float(RAIN["first"]) + rng.randf() * float(RAIN["spread"])
		(r["marks"] as Array).append({"kind": "rain", "x": p.x, "z": p.y, "r": RAIN["radius"], "from": now, "at": at, "ore": rng.randf() < float(RAIN["ore"])})
	if phase == 2:
		for i in CALL_TICKS:
			var a := rng.randf() * TAU
			var p := sim.state().push_out_of_rock(center() + Vector2.from_angle(a) * (ROOM - 3.0))
			var t := Enemy.make("tick", p.x, p.y, 0.6 + 0.2 * i)
			t.beast = true
			GameState.enemies.append(t)
			Combat.zone(p.x, p.y, 2.0, Color("#b4a07a"))
	Sfx.at("vague", e.x, e.z)


## Le sillon : une droite à travers la salle, par l'unité visée, du bord où elle est au bord opposé.
static func _start_furrow(sim: Simulation, r: Dictionary, e: Enemy, target: Unit) -> void:
	var c := center()
	var dir := (target.pos() - e.pos()).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	# Corde de la salle qui passe par la cible, dans cette direction.
	var rel := target.pos() - c
	var b := rel.dot(dir)
	var disc := maxf(0.0, b * b - rel.length_squared() + (ROOM - 2.0) * (ROOM - 2.0))
	var a_pt := target.pos() + dir * (-b - sqrt(disc))
	var b_pt := target.pos() + dir * (-b + sqrt(disc))
	r["furrow"] = {"a": a_pt, "b": b_pt, "from": GameState.sim_time + float(FURROW["sink"]), "hit": []}
	_go(r, "furrow_sink", FURROW["sink"])
	sim.say("La Gorge-Cuivre laboure la salle : sortez de sa ligne !", 3.0)


## Unités fauchées entre deux positions de la butte (une fois chacune).
static func _furrow_hits(sim: Simulation, r: Dictionary, a: Vector2, b: Vector2, alive: Array[Unit]) -> void:
	var hit: Array = (r["furrow"] as Dictionary)["hit"]
	for u: Unit in alive:
		if u.hidden or hit.has(u):
			continue
		var p := Geometry2D.get_closest_point_to_segment(u.pos(), a, b)
		if p.distance_to(u.pos()) <= float(FURROW["width"]):
			hit.append(u)
			sim.combat.damage(u, Combat.boss_shot(u.z) if u.role == "engineer" else Combat.after_armor(u, FURROW["damage"] * Biomes.power_at(u.z)))
			Combat.flash(u.x, u.z, Color("#f0b088"))


static func _squad(sim: Simulation, at: Vector2) -> void:
	var st := sim.state()
	var stats := Catalog.menace_stats(Catalog.menace_tier(GameState.menace) + Biomes.threat_tiers(2), true)
	for k in FURROW_SQUAD.size():
		var p := st.push_out_of_rock(at + Vector2.from_angle(float(k) / FURROW_SQUAD.size() * TAU) * 2.4)
		var e := Enemy.make(FURROW_SQUAD[k], p.x, p.y, 0.6 + 0.2 * k, stats)
		e.beast = true
		GameState.enemies.append(e)
	Combat.zone(at.x, at.y, 5.0, Color("#b4a07a"))
