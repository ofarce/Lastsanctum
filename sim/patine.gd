class_name Patine
extends RefCounted
## La Martyre de la Patine : mini-boss 2 des Salles oubliées (planches/mini-boss-temple-veines-propositions.html, M1
## validé le 2026-11-22 ; dessin : planches/mini-boss-biome2-rendu.html, silhouette P1 « L'Automate verdi » choisie le
## 2026-11-25, atlas assets/imported/miniboss2/ exportés par tools/miniboss2/export.py).
##
## L'armure d'automate de Byrsa virée au vert-de-gris, dans la Nef verte (salle « mb2 » du plan des Salles oubliées,
## quartier B). Elle se dresse quand un allié entre dans la salle et lève un dôme de RADIUS unités centré sur l'arène :
## comme la Martyre de Byrsa, seul l'Exilé y entre et seul l'Exilé, dedans, la blesse ; rien ne vise à travers.
## - Pluie de cuivre : deux anneaux de balles cuivrées qui s'éloignent d'elle en tournant en sens inverse.
## - Salve : un éventail de balles vers l'Exilé.
## - Vert-de-gris : une balle qui n'a rien touché s'arrête (au bout de sa course ou au bord du dôme) et reste
##   MINE.life s en mine verte ; l'Exilé qui marche dessus la fait éclater. L'arène se remplit.
## - Polir : une balle de l'Exilé qui passe sur une mine l'efface ; chaque mine effacée avance de POLISH_VEIL s la
##   recharge de son Voile (module d'exo de la Martyre de Byrsa).
## - Phase II (sous la moitié des PV), oxydation : ses fissures s'allument, puis toutes les mines éclatent ensemble,
##   chacune en croix (quatre balles qui ne redeviennent pas des mines).
## S'il ressort du dôme, elle regagne le centre, ses balles s'éteignent (les mines restent) ; s'il tombe, elle
## retrouve ses PV et le dôme se vide de ses mines.
## Sa chute ouvre la porte « mb2@veines » (route de la Gorge) et allume le portail de l'arène ; elle lâche la Clef de la
## Gorge et le plan des Mines de patine (Loot).
## État : GameState.patine = {state, seed, e, rect, room, center, mode, t0, until, next_at, idx, bullets, mines,
## iframe_until, phase, strike_at}. Rendu : world/miniboss2/patine_view.gd (boss) et patine_fx.gd (dôme, balles,
## mines).

const KIND := "patine"
## Silhouette (atlas : 56 × 76, ~30 px de large sans les bras), en unités au sol.
const BODY := {"half_w": 2.2, "top": 8.6, "foot": 0.8, "melee": 1.4}
const PHASE_HP := 0.5
const PHASE_NAMES := ["I · La pluie de cuivre", "II · L’oxydation"]
## Dôme : rayon (l'arène fait 40 unités du nord au sud) ; les autres unités sont rejetées à EDGE au-delà du bord.
const RADIUS := 18.0
const EDGE := 0.6
## Balles : rayon, zone qui encaisse chez l'Exilé, dégâts (coup de boss, Combat.boss_shot ; ceux-ci servent au rendu).
const BULLET := {"r": 0.3, "hit": 0.375, "lift": 17.0}
const IFRAMES := 0.6
## Pluie de cuivre : balles par anneau, vitesse d'éloignement, rotation (rad/s, un anneau dans chaque sens), course
## (tirée entre min et max avant l'arrêt), second anneau décalé de « second » s.
const RAIN := {"count": 14, "speed": 5.5, "spin": 0.55, "min": 5.0, "max": 16.0, "second": 0.35, "time": 1.2}
## Salve : balles, ouverture, vitesse, course, délai après le geste.
const VOLLEY := {"count": 5, "spread": deg_to_rad(40.0), "speed": 9.0, "min": 8.0, "max": 20.0, "delay": 0.4, "time": 1.0}
## Mines : durée de vie, rayon de contact, rayon touché par une balle de l'Exilé.
const MINE := {"life": 6.0, "touch": 0.65, "polish": 0.8, "max": 90}
const POLISH_VEIL := 4.0
## Oxydation : geste, puis éclatement en croix (vitesse des éclats).
const OX := {"time": 0.75, "burst": 0.55, "speed": 7.0}
## Au contact : elle repousse de la paume (geste « cast »).
const STRIKE := {"reach": 2.4, "hit": 0.4, "time": 0.6, "cd": 2.2}
const SPEED_WALK := 2.0
const REST := [1.3, 1.0]
const FIRST := 1.8
const ROTATION := [["rain", "volley", "rain"], ["rain", "ox", "volley", "ox"]]

const QUOTE_WAIT := "Une autre Martyre, rongée de vert-de-gris. Son dôme ne laisse passer que moi."
const QUOTE_DUEL := "Ses balles s’arrêtent et deviennent des mines. Je dois les polir à l’Arbalestrie avant que la nef se referme."
const QUOTE_OX := "Ses fissures s’allument : toutes les mines vont éclater !"
const QUOTE_DONE := "La Martyre de la Patine tombe en poussière verte. La route de la Gorge s’ouvre."


static func run() -> Dictionary:
	return GameState.patine


static func boss() -> Enemy:
	return GameState.patine.get("e")


## Sur le terrain, vivante : dôme levé.
static func active() -> bool:
	var e := boss()
	return e != null and e.hp > 0.0 and String(GameState.patine.get("mode", "sleep")) != "sleep"


static func dead() -> bool:
	return String(GameState.patine.get("mode", "")) == "dead"


static func center() -> Vector2:
	return GameState.patine.get("center", Vector2.ZERO)


static func phase_of(e: Enemy) -> int:
	return 1 if e.hp <= e.max_hp * PHASE_HP else 0


static func arena_room(st: TerrainState) -> Dictionary:
	if st == null or st.veines_layout.is_empty():
		return {}
	for room: Dictionary in st.veines_layout["rooms"]:
		if room["role"] == "mb2":
			return room
	return {}


static func in_room(p: Vector2) -> bool:
	var rr: Rect2i = run().get("rect", Rect2i())
	return rr.size != Vector2i.ZERO and rr.has_point(Vector2i(floori(p.x / 4.0), floori(p.y / 4.0)))


## p (unité, ennemi, {x, z}) sous le dôme.
static func inside(p: Variant) -> bool:
	var dx: float = p.x - center().x
	var dz: float = p.z - center().y
	return dx * dx + dz * dz < RADIUS * RADIUS


static func blocks(a: Variant, b: Variant) -> bool:
	return active() and inside(a) != inside(b)


static func can_hurt(src: Unit) -> bool:
	return src != null and src.role == "engineer" and inside(src)


## L'Exilé en duel (vivant, visible, sous le dôme), sinon null.
static func duelist() -> Unit:
	if not active():
		return null
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden and inside(u):
			return u
	return null


static func blinking(u: Unit) -> bool:
	var t := GameState.sim_time
	return u.role == "engineer" and t < float(run().get("iframe_until", -INF)) and fmod(t * 20.0, 2.0) < 1.0


static func tick(sim: Simulation) -> void:
	if GameState.ended or sim.world == null:
		return
	var st := sim.state()
	var room := arena_room(st)
	if room.is_empty():
		return
	var r := GameState.patine
	if r.get("state") != st or r.get("seed") != st.seed:
		_setup(st, r, room)
	var e := boss()
	if e != null and e.hp <= 0.0 and not dead():
		r["mode"] = "dead"
		r["down_at"] = GameState.sim_time
		for b: Dictionary in r["bullets"]:
			r["motes"].append({"x": b["x"], "z": b["z"], "at": GameState.sim_time})
		r["bullets"] = []
		r["mines"] = []
		RoomEncounters.open_door(sim, "mb2@veines")
		sim.say(QUOTE_DONE, 4.0)
		Sfx.at("vague", e.x, e.z)
		return
	if String(r["mode"]) == "sleep":
		for u: Unit in GameState.units:
			if u.alive() and not u.hidden and in_room(u.pos()):
				_rise(sim, r)
				break
	if active():
		enforce(sim)


static func _setup(st: TerrainState, r: Dictionary, room: Dictionary) -> void:
	r.clear()
	r["state"] = st
	r["seed"] = st.seed
	var rr: Rect2i = room["rect"]
	r["rect"] = rr
	r["room"] = room["id"]
	var c := Vector2(rr.position * 4.0) + Vector2(rr.size * 4.0) / 2.0
	if not st.walkable(c.x, c.y):
		c = st.push_out_of_rock(c)
	r["center"] = c
	r["mode"] = "sleep"
	r["idx"] = 0
	r["next_at"] = INF
	r["until"] = -INF
	r["t0"] = -INF
	r["bullets"] = []
	r["mines"] = []
	r["motes"] = []
	r["events"] = []
	r["iframe_until"] = -INF
	r["strike_at"] = INF
	r["phase"] = 0
	r["duel"] = false
	var e := Enemy.make(KIND, c.x, c.y, 1.0)
	e.beast = true
	e.hidden = true
	e.face = -1
	r["e"] = e
	GameState.enemies.append(e)


static func _rise(sim: Simulation, r: Dictionary) -> void:
	var e := boss()
	e.hidden = false
	r["mode"] = "idle"
	r["risen_at"] = GameState.sim_time
	Combat.zone(e.x, e.z, 6.0, Color("#78e098"))
	Combat.flash(e.x, e.z, Color("#2aa452"))
	Sfx.play("martyre")
	sim.say(QUOTE_WAIT, 4.0)
	enforce(sim)


static func _go(r: Dictionary, mode: String, seconds: float) -> void:
	r["mode"] = mode
	r["t0"] = GameState.sim_time
	r["until"] = GameState.sim_time + seconds


## L'Exilé est tombé pendant le duel : elle retrouve ses PV, sa première phase, et le dôme se vide.
static func reset_duel() -> void:
	var e := boss()
	if e == null or e.hp <= 0.0 or not active():
		return
	e.hp = e.max_hp
	var r := run()
	r["phase"] = 0
	r["idx"] = 0
	r["bullets"] = []
	r["mines"] = []
	r["events"] = []


## Comportement (à la place de celui des autres ennemis, Combat.update_enemies).
static func act(sim: Simulation, e: Enemy, dt: float) -> void:
	var r := run()
	if r.is_empty() or r.get("e") != e or String(r["mode"]) == "sleep":
		return
	e.stun = 0.0
	e.cooldown -= dt
	var now := GameState.sim_time
	var u := duelist()
	if u != null and not r["duel"]:
		r["duel"] = true
		r["next_at"] = now + FIRST
		if not r.get("told", false):
			r["told"] = true
			sim.say(QUOTE_DUEL, 5.0)
	elif u == null and r["duel"]:
		r["duel"] = false
		r["next_at"] = INF
		r["events"] = []
		r["strike_at"] = INF
		for b: Dictionary in r["bullets"]:
			r["motes"].append({"x": b["x"], "z": b["z"], "at": now})
		r["bullets"] = []
		_go(r, "idle", 0.0)
	_events(sim, e, u, now)
	_bullets(sim, u, now, dt)
	_mines(sim, u, now)
	r["motes"] = (r["motes"] as Array).filter(func(m: Dictionary) -> bool: return now - float(m["at"]) < 0.9)
	if now >= float(r["strike_at"]):
		r["strike_at"] = INF
		if u != null and Combat.dist(e, u) <= STRIKE["reach"] + 0.8:
			_hurt(sim, u, now)
			var push := (u.pos() - e.pos()).normalized() * 3.0
			var p := u.pos() + push
			if sim.state().walkable(p.x, p.y) and inside({"x": p.x, "z": p.y}):
				u.x = p.x
				u.z = p.y
		Combat.zone(e.x, e.z, STRIKE["reach"], Color("#78e098"))
	if u != null:
		var ph := phase_of(e)
		if ph > int(r["phase"]):
			r["phase"] = ph
			sim.say("Phase %s." % PHASE_NAMES[ph], 3.0)
			Combat.flash(e.x, e.z, Color("#78e098"))
			r["next_at"] = maxf(float(r["next_at"]), now + 1.0)
	var mode := String(r["mode"])
	if mode != "idle" and now >= float(r["until"]):
		_go(r, "idle", 0.0)
		mode = "idle"
	if mode != "idle" and mode != "walk":
		return
	if u == null:
		if e.pos().distance_to(center()) > 1.0:
			_walk(sim, e, center(), dt)
		return
	e.face = -1 if u.x < e.x else 1
	if now >= float(r["next_at"]):
		var rot: Array = ROTATION[int(r["phase"])]
		var p: String = rot[int(r["idx"]) % rot.size()]
		r["idx"] = int(r["idx"]) + 1
		_start(sim, e, r, u, p, now)
		return
	var d := Combat.dist(e, u)
	if d <= STRIKE["reach"] and e.cooldown <= 0.0:
		e.cooldown = STRIKE["cd"]
		e.cast_started = now
		r["strike_at"] = now + STRIKE["hit"]
		_go(r, "cast", STRIKE["time"])
		return
	if d > STRIKE["reach"] * 0.8:
		_walk(sim, e, u.pos(), dt)


static func _start(sim: Simulation, e: Enemy, r: Dictionary, u: Unit, p: String, now: float) -> void:
	var rest: float = REST[int(r["phase"])]
	match p:
		"ox":
			if (r["mines"] as Array).is_empty():
				_start(sim, e, r, u, "rain", now)
				return
			_go(r, "ox", OX["time"])
			r["events"].append({"at": now + OX["burst"], "kind": "burst"})
			sim.say(QUOTE_OX, 2.5)
			Sfx.at("bouclier_forme", e.x, e.z)
			r["next_at"] = now + OX["time"] + rest
		"volley":
			e.cast_started = now
			_go(r, "cast", VOLLEY["time"])
			r["events"].append({"at": now + VOLLEY["delay"], "kind": "volley"})
			r["next_at"] = now + VOLLEY["time"] + rest
		_:
			e.cast_started = now
			_go(r, "cast", RAIN["time"])
			var off := sim.rng.randf() * TAU
			r["events"].append({"at": now + 0.3, "kind": "ring", "spin": RAIN["spin"], "off": off})
			r["events"].append({"at": now + 0.3 + RAIN["second"], "kind": "ring", "spin": -RAIN["spin"], "off": off + PI / RAIN["count"]})
			r["next_at"] = now + RAIN["time"] + rest
	Sfx.at("sort_lumiere", e.x, e.z)


static func _events(sim: Simulation, e: Enemy, u: Unit, now: float) -> void:
	var r := run()
	var keep: Array = []
	for ev: Dictionary in r["events"]:
		if now < float(ev["at"]):
			keep.append(ev)
			continue
		match String(ev["kind"]):
			"ring":
				var n: int = RAIN["count"]
				for i in n:
					_shoot(sim, e.pos(), float(ev["off"]) + i * TAU / n, RAIN["speed"], float(ev["spin"]),
						lerpf(RAIN["min"], RAIN["max"], sim.rng.randf()), true)
			"volley":
				if u == null:
					continue
				var a := (u.pos() - e.pos()).angle()
				var n: int = VOLLEY["count"]
				for i in n:
					_shoot(sim, e.pos(), a + VOLLEY["spread"] * (i / float(n - 1) - 0.5), VOLLEY["speed"], 0.0,
						lerpf(VOLLEY["min"], VOLLEY["max"], sim.rng.randf()), true)
			"burst":
				# Toutes les mines éclatent en croix ; les éclats ne redeviennent pas des mines.
				for m: Dictionary in r["mines"]:
					for k in 4:
						var b := _shoot(sim, Vector2(m["x"], m["z"]), k * PI / 2.0, OX["speed"], 0.0, RADIUS * 2.0, false)
						b["r0"] = 0.0
					r["motes"].append({"x": m["x"], "z": m["z"], "at": now})
				r["mines"] = []
				Combat.flash(e.x, e.z, Color("#78e098"))
	r["events"] = keep


## Nouvelle balle partant de o (angle a, vitesse radiale v, rotation spin autour de o) ; elle s'arrête au bout de
## `travel` unités (mine si `mine`).
static func _shoot(_sim: Simulation, o: Vector2, a: float, v: float, spin: float, travel: float, mine: bool) -> Dictionary:
	var b := {"ox": o.x, "oz": o.y, "rad": 0.6, "a": a, "v": v, "spin": spin, "travel": travel, "mine": mine,
		"x": o.x + cos(a) * 0.6, "z": o.y + sin(a) * 0.6, "r0": 0.6}
	run()["bullets"].append(b)
	return b


static func _bullets(sim: Simulation, u: Unit, now: float, dt: float) -> void:
	var r := run()
	var keep: Array = []
	var c := center()
	for b: Dictionary in r["bullets"]:
		b["rad"] = float(b["rad"]) + float(b["v"]) * dt
		b["a"] = float(b["a"]) + float(b["spin"]) * dt
		var px := float(b["ox"]) + cos(b["a"]) * float(b["rad"])
		var pz := float(b["oz"]) + sin(b["a"]) * float(b["rad"])
		b["vx"] = (px - float(b["x"])) / maxf(dt, 1e-4)
		b["vz"] = (pz - float(b["z"])) / maxf(dt, 1e-4)
		b["x"] = px
		b["z"] = pz
		if u != null:
			var dx := u.x - px
			var dz := u.z - pz
			var reach: float = BULLET["hit"] + BULLET["r"]
			if dx * dx + dz * dz < reach * reach and _hurt(sim, u, now):
				Combat.flash(u.x, u.z, Color("#eab07a"))
				continue
		var out := Vector2(px, pz).distance_to(c) > RADIUS - 0.4
		if out or float(b["rad"]) >= float(b["travel"]):
			if b["mine"] and (r["mines"] as Array).size() < MINE["max"]:
				var p := Vector2(px, pz)
				if out:
					p = c + (p - c).limit_length(RADIUS - 0.6)
				r["mines"].append({"x": p.x, "z": p.y, "at": now, "until": now + MINE["life"]})
			else:
				r["motes"].append({"x": px, "z": pz, "at": now})
			continue
		keep.append(b)
	r["bullets"] = keep


static func _mines(sim: Simulation, u: Unit, now: float) -> void:
	var r := run()
	var keep: Array = []
	for m: Dictionary in r["mines"]:
		if now >= float(m["until"]):
			r["motes"].append({"x": m["x"], "z": m["z"], "at": now})
			continue
		if u != null and Vector2(m["x"], m["z"]).distance_to(u.pos()) < MINE["touch"] and _hurt(sim, u, now):
			Combat.flash(m["x"], m["z"], Color("#78e098"))
			r["motes"].append({"x": m["x"], "z": m["z"], "at": now})
			continue
		keep.append(m)
	r["mines"] = keep


## Coup porté à l'Exilé, sauf pendant son invulnérabilité ; renvoie s'il a porté.
static func _hurt(sim: Simulation, u: Unit, now: float) -> bool:
	var r := run()
	if now < float(r["iframe_until"]):
		return false
	sim.combat.damage(u, Combat.boss_shot(u.z))
	r["iframe_until"] = now + IFRAMES
	return true


## Une balle de l'Exilé (from → end) efface les mines qu'elle survole ; chacune avance la recharge de son Voile.
static func polish(u: Unit, from: Vector2, end: Vector2) -> void:
	var r := run()
	if r.is_empty() or (r.get("mines", []) as Array).is_empty() or not inside(u):
		return
	var keep: Array = []
	var n := 0
	for m: Dictionary in r["mines"]:
		var p := Vector2(m["x"], m["z"])
		var q := Geometry2D.get_closest_point_to_segment(p, from, end)
		if q.distance_to(p) <= MINE["polish"]:
			n += 1
			r["motes"].append({"x": p.x, "z": p.y, "at": GameState.sim_time, "polish": true})
			continue
		keep.append(m)
	if n == 0:
		return
	r["mines"] = keep
	u.veil_ready_at -= POLISH_VEIL * n
	Sfx.at("bouclier_dore", end.x, end.y)


static func _walk(sim: Simulation, e: Enemy, goal: Vector2, dt: float) -> void:
	var next := sim.steer(e, goal)
	var p := e.pos() + (next - e.pos()).limit_length(SPEED_WALK * dt)
	var off := p - center()
	p = center() + off.limit_length(RADIUS - 1.5)
	if sim.state().walkable(p.x, p.y):
		if absf(p.x - e.x) > 0.01:
			e.face = -1 if p.x < e.x else 1
		e.x = p.x
		e.z = p.y
		run()["walking_at"] = GameState.sim_time


static func walking() -> bool:
	return GameState.sim_time - float(run().get("walking_at", -INF)) < 0.15


## Le dôme repousse au bord tout ce qui n'est ni elle ni l'Exilé.
static func enforce(sim: Simulation) -> void:
	if not active():
		return
	var c := center()
	for u: Unit in GameState.units:
		if u.role == "engineer" or not u.alive() or u.hidden or not inside(u):
			continue
		var p := _push_out(sim, u.pos(), c)
		u.x = p.x
		u.z = p.y
		u.tx = p.x
		u.tz = p.y
		u.force_move = false
	for o: Enemy in GameState.enemies:
		if o == boss() or o.hp <= 0.0 or o.hidden or not inside(o):
			continue
		var p := _push_out(sim, o.pos(), c)
		o.x = p.x
		o.z = p.y


static func _push_out(sim: Simulation, p: Vector2, c: Vector2) -> Vector2:
	var off := p - c
	if off.length() < 0.01:
		off = Vector2(0.0, 1.0)
	var q := c + off.normalized() * (RADIUS + EDGE)
	return q if sim.state().walkable(q.x, q.y) else sim.state().push_out_of_rock(q)


static func objective() -> Dictionary:
	if not active():
		return {}
	var e := boss()
	return {"id": "patine", "quest": "La Martyre de la Patine", "interrupt": true,
		"label": "Éliminer la Martyre de la Patine en combat singulier",
		"quote": "", "done_quote": "",
		"value": "%d PV" % ceili(e.hp), "progress": 1.0 - e.hp / e.max_hp}
