class_name Eclusier
extends RefCounted
## L'Éclusier de Byrsa : mini-boss 1 des Salles oubliées (planches/mini-boss-temple-veines-propositions.html, V1 validé
## le 2026-11-22 ; dessin : planches/mini-boss-biome2-rendu.html, silhouette E2 « Le Porte-clef » choisie le
## 2026-11-25, atlas assets/imported/miniboss2/ exportés par tools/miniboss2/export.py).
##
## Un ingénieur de Byrsa en scaphandre de cuivre, dans la Grande Écluse (salle « mb1 » du plan des Salles oubliées,
## quartier A). Il dort, invisible, jusqu'à ce qu'un allié entre dans la salle. On le combat avec l'escouade.
## La salle est noyée : elle est coupée en quatre quarts ; celui où débouche le couloir d'entrée reste sec, les trois
## autres ont chacun une pompe contre la paroi et une anguille qui ne sort que quand son quart est sous l'eau.
## - Eau : un quart noyé ralentit la marche de moitié (SLOW) et met à portée de son anguille.
## - Pompes : un adepte posté à moins de PUMP_R d'une pompe vide son quart, puis le garde sec. Salle sèche : son
##   scaphandre se vide et son armure tombe de ARMOR à 0.
## - Ouverture des vannes : il plante sa clef, l'eau remonte dans un quart (de préférence un quart sec, celui de
##   l'Exilé s'il y est) ; une pompe tenue l'en empêche.
## - Harpon à chaîne : annoncé HARPOON.warn s (trait doré), il attire une unité jusqu'à lui (un adepte aux pompes de
##   préférence) ; trois tirs de l'Exilé sur la chaîne la brisent. Arrivée au bout : coup de clef et étourdissement.
## - Phase II (sous la moitié des PV), court-circuit : annoncé SHORT.warn s, l'eau s'électrise SHORT.time s et
##   retire SHORT.dps PV par seconde à tout ce qui s'y trouve, alliés comme anguilles.
## - Au contact, il abat sa clef devant lui.
## Sa chute ouvre la porte « mb1@veines » vers les Écluses et allume le portail de l'arène ; il lâche le plan de la
## Culasse froide, la Clef des Écluses et le hublot de son scaphandre (Loot).
## État : GameState.eclusier = {state, seed, e, rect, room, center, quarters, mode, t0, until, next_at, idx, harpoon,
## short, alone, dry}. Rendu : world/miniboss2/eclusier_view.gd (boss) et eclusier_water.gd (eau, pompes, chaîne).

const KIND := "eclusier"
## Silhouette au sol (unités ; 8 px natifs par unité) : 36 px de large sans la clef, 70 px de haut.
const BODY := {"half_w": 2.3, "top": 8.4, "foot": 0.6, "melee": 1.4}
const PHASE_NAMES := ["I · Les vannes", "II · Le court-circuit"]
const PHASE_HP := 0.5
const ARMOR := 5.0
## Eau d'un quart : montée et vidange (niveau par seconde), niveau à partir duquel elle ralentit et fait sortir
## l'anguille, ralentissement de la marche.
const RISE := 0.5
const DRAIN := 0.34
const WET := 0.4
const SLOW := 0.5
## Un adepte à moins de PUMP_R unités d'une pompe la tient ; la pompe est à PUMP_IN unités de la paroi.
const PUMP_R := 3.0
const PUMP_IN := 3.0
## Anguilles de la salle : portée de leur décharge.
const EEL_REACH := 8.0
## Gestes (s) : l'eau monte à l'image de la gerbe (VANNE.splash) ; la clef s'abat au contact (STRIKE).
const VANNE := {"time": 0.75, "splash": 0.5}
const STRIKE := {"time": 0.75, "hit": 0.5, "reach": 2.4, "cd": 2.0, "stun": 0.0}
## Harpon : annonce, vitesse de la tête, vitesse de traction, durée maximale de la traction, tirs qui brisent la
## chaîne, portée, dégâts et étourdissement à l'arrivée, rayon de la chaîne pour les tirs, chaîne brisée affichée.
const HARPOON := {"warn": 0.6, "speed": 30.0, "pull": 9.0, "max": 3.5, "breaks": 3, "range": 34.0,
	"damage": 20.0, "stun": 0.8, "chain_r": 0.9, "broken": 0.6, "pumper": 0.6}
const SHORT := {"warn": 1.2, "time": 3.0, "dps": 15.0, "every": 0.25}
## Repos entre deux attaques, par phase ; délai de la première attaque ; oubli sans personne dans la salle.
const REST := [1.8, 1.3]
const FIRST := 1.6
const FORGET := 8.0
const ROTATION := [["vanne", "harpoon"], ["short", "harpoon", "vanne", "harpoon"]]

const QUOTE_WAKE := "Un ingénieur de Byrsa, dans un scaphandre plein d’eau. Tant que la salle est noyée, rien ne le perce : il faut tenir ses pompes."
const QUOTE_DRY := "La salle est sèche : son scaphandre se vide. Il n’a plus d’armure."
const QUOTE_WET := "L’eau remonte : son scaphandre se remplit."
const QUOTE_SHORT := "Il électrise l’eau ! Sortez des quarts noyés."
const QUOTE_DONE := "L’Éclusier s’effondre. La porte des Écluses s’ouvre."


static func run() -> Dictionary:
	return GameState.eclusier


static func boss() -> Enemy:
	return GameState.eclusier.get("e")


## En combat : éveillé et vivant (barre de boss, pas de sauvegarde).
static func active() -> bool:
	var e := boss()
	return e != null and e.hp > 0.0 and String(GameState.eclusier.get("mode", "sleep")) != "sleep"


static func dead() -> bool:
	return String(GameState.eclusier.get("mode", "")) == "dead"


static func center() -> Vector2:
	return GameState.eclusier.get("center", Vector2.ZERO)


static func phase_of(e: Enemy) -> int:
	return 1 if e.hp <= e.max_hp * PHASE_HP else 0


## Arène de l'Éclusier dans le plan des Salles oubliées (mini-boss 1, quartier A), ou {} sans plan.
static func arena_room(st: TerrainState) -> Dictionary:
	if st == null or st.veines_layout.is_empty():
		return {}
	for room: Dictionary in st.veines_layout["rooms"]:
		if room["role"] == "mb1":
			return room
	return {}


static func in_room(p: Vector2) -> bool:
	var rr: Rect2i = run().get("rect", Rect2i())
	return rr.size != Vector2i.ZERO and rr.has_point(Vector2i(floori(p.x / 4.0), floori(p.y / 4.0)))


## Quart de la salle sous p, ou {}.
static func quarter_at(p: Vector2) -> Dictionary:
	for q: Dictionary in run().get("quarters", []):
		if (q["rect"] as Rect2).has_point(p):
			return q
	return {}


## Niveau de l'eau sous (x, z) (0 hors de la salle).
static func water_at(x: float, z: float) -> float:
	if run().is_empty():
		return 0.0
	var q := quarter_at(Vector2(x, z))
	return 0.0 if q.is_empty() else float(q["level"])


## Ralentissement de la marche sous (x, z) : SLOW dans un quart noyé, 1 ailleurs.
static func slow_at(x: float, z: float) -> float:
	return SLOW if water_at(x, z) >= WET else 1.0


## Il reste de l'eau dans la salle (armure pleine).
static func wet() -> bool:
	for q: Dictionary in run().get("quarters", []):
		if float(q["level"]) > 0.05:
			return true
	return false


## Unités visibles dans la salle.
static func squad() -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and in_room(u.pos()):
			out.append(u)
	return out


static func tick(sim: Simulation, dt: float) -> void:
	if GameState.ended or sim.world == null:
		return
	var st := sim.state()
	var room := arena_room(st)
	if room.is_empty():
		return
	var r := GameState.eclusier
	if r.get("state") != st or r.get("seed") != st.seed:
		_setup(sim, st, r, room)
	var e := boss()
	if e != null and e.hp <= 0.0 and not dead():
		r["mode"] = "dead"
		r["down_at"] = GameState.sim_time
		r["harpoon"] = {}
		r["short"] = {}
		for q: Dictionary in r["quarters"]:
			q["flooded"] = false
		RoomEncounters.open_door(sim, "mb1@veines")
		sim.say(QUOTE_DONE, 4.0)
		Sfx.at("vague", e.x, e.z)
	_water(sim, r, dt)


static func _setup(sim: Simulation, st: TerrainState, r: Dictionary, room: Dictionary) -> void:
	r.clear()
	r["state"] = st
	r["seed"] = st.seed
	var rr: Rect2i = room["rect"]
	r["rect"] = rr
	r["room"] = room["id"]
	var box := Rect2(rr.position * 4.0, rr.size * 4.0)
	var c := box.get_center()
	r["center"] = c
	# Le quart sec : celui où débouche le couloir d'entrée (bout du couloir le plus proche de la salle).
	var entry := c + Vector2(0.0, box.size.y)
	for l: Dictionary in st.veines_layout["links"]:
		if l["kind"] != "corridor" or (l["a"] != room["id"] and l["b"] != room["id"]):
			continue
		var path: Array = l["path"]
		for i in range(1, path.size()):
			var p0 := Vector2(path[i - 1]) * 4.0 + Vector2(2.0, 2.0)
			var p1 := Vector2(path[i]) * 4.0 + Vector2(2.0, 2.0)
			if box.has_point(p0) != box.has_point(p1):
				entry = p0 if box.has_point(p0) else p1
	entry = Vector2(clampf(entry.x, box.position.x + 1.0, box.end.x - 1.0), clampf(entry.y, box.position.y + 1.0, box.end.y - 1.0))
	var quarters: Array[Dictionary] = []
	var hw := box.size.x / 2.0
	var hh := box.size.y / 2.0
	var k := 0
	for qy in 2:
		for qx in 2:
			var qr := Rect2(box.position + Vector2(qx * hw, qy * hh), Vector2(hw, hh))
			var door := qr.has_point(entry)
			var q := {"rect": qr, "door": door, "flooded": not door, "level": 0.0 if door else 1.0, "manned": false,
				"pump": Vector2.INF, "eel": null, "i": k}
			k += 1
			if not door:
				# Pompe contre la paroi est ou ouest du quart, à mi-hauteur ; anguille dans le coin opposé au centre.
				var pp := Vector2(box.position.x + PUMP_IN if qx == 0 else box.end.x - PUMP_IN, qr.get_center().y)
				q["pump"] = st.push_out_of_rock(pp) if not st.walkable(pp.x, pp.y) else pp
				var ep := Vector2(qr.position.x + (5.0 if qx == 0 else hw - 5.0), qr.position.y + (5.0 if qy == 0 else hh - 5.0))
				if qx == 0:
					ep.x += 6.0
				else:
					ep.x -= 6.0
				var eel := _eel(st.push_out_of_rock(ep) if not st.walkable(ep.x, ep.y) else ep)
				q["eel"] = eel
			quarters.append(q)
	r["quarters"] = quarters
	r["mode"] = "sleep"
	r["idx"] = 0
	r["next_at"] = INF
	r["until"] = -INF
	r["t0"] = -INF
	r["alone"] = 0.0
	r["harpoon"] = {}
	r["short"] = {}
	r["dry"] = false
	r["strike_at"] = INF
	var e := Enemy.make(KIND, c.x, c.y, 0.0)
	e.beast = true
	e.hidden = true
	e.face = -1
	r["e"] = e
	GameState.enemies.append(e)


## Anguille de la salle : la faune du bassin (Wildlife.tick la mène), cachée tant que son quart est sec.
static func _eel(p: Vector2) -> Enemy:
	var K: Dictionary = Wildlife.KINDS["eel"]
	var e := Enemy.make("eel", p.x, p.y, 1.0)
	e.hp = K["hp"]
	e.max_hp = K["hp"]
	e.speed = 0.0
	e.reach = EEL_REACH
	e.damage = K["damage"] * Biomes.power_at(p.y)
	e.beast = true
	e.neutral = true
	e.hidden = true
	e.home = p
	e.memo["eclusier"] = true
	GameState.enemies.append(e)
	return e


## Pompes tenues, montée et vidange de l'eau, anguilles qui sortent ou plongent, armure du scaphandre.
static func _water(sim: Simulation, r: Dictionary, dt: float) -> void:
	var e := boss()
	for q: Dictionary in r["quarters"]:
		if q["door"]:
			continue
		var manned := false
		if not dead():
			for u: Unit in GameState.units:
				if u.alive() and not u.hidden and sim.is_adept(u) and u.pos().distance_to(q["pump"]) <= PUMP_R:
					manned = true
					break
		if manned != bool(q["manned"]):
			q["manned"] = manned
			if manned:
				Sfx.at("portail", q["pump"].x, q["pump"].y)
		var lv := float(q["level"])
		if manned or not q["flooded"]:
			lv = maxf(0.0, lv - DRAIN * dt)
			if lv <= 0.0:
				q["flooded"] = false
		else:
			lv = minf(1.0, lv + RISE * dt)
		q["level"] = lv
		var eel: Enemy = q["eel"]
		if eel != null and eel.hp > 0.0:
			var up := lv >= WET and not dead() and String(r["mode"]) != "sleep"
			if eel.hidden == up:
				eel.hidden = not up
				if up:
					Combat.zone(eel.x, eel.z, 1.6, Color("#3a8a9a"))
	if e == null or e.hp <= 0.0:
		return
	var is_wet := wet()
	e.armor = ARMOR if is_wet else 0.0
	if bool(r["dry"]) == is_wet:
		r["dry"] = not is_wet
		if String(r["mode"]) != "sleep":
			sim.say(QUOTE_WET if is_wet else QUOTE_DRY, 3.0)
			Combat.flash(e.x, e.z, Color("#74cad6") if is_wet else Color("#ddb457"))


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
	var here: Array[Unit] = []
	for u: Unit in alive:
		if not u.hidden and in_room(u.pos()):
			here.append(u)
	here.sort_custom(func(a: Unit, b: Unit) -> bool: return a.pos().distance_squared_to(e.pos()) < b.pos().distance_squared_to(e.pos()))
	if String(r["mode"]) == "sleep":
		if here.is_empty():
			return
		e.hidden = false
		_go(r, "idle", 0.0)
		r["next_at"] = now + FIRST
		sim.say(QUOTE_WAKE, 5.0)
		Sfx.at("vague", e.x, e.z)
		Combat.zone(e.x, e.z, 4.0, Color("#74cad6"))
		return
	_harpoon_tick(sim, e, r, now, dt)
	_short_tick(sim, e, r, now)
	_strike_tick(sim, e, r, here, now)
	var mode := String(r["mode"])
	if mode == "vanne" and now >= float(r["t0"]) + VANNE["splash"] and not r.get("splashed", false):
		r["splashed"] = true
		_flood(sim, r, here)
	if mode in ["vanne", "strike", "harpoon", "short"] and now >= float(r["until"]):
		_go(r, "idle", 0.0)
		mode = "idle"
	# Salle vide : il se tait, harpon et court-circuit retombent.
	r["alone"] = 0.0 if not here.is_empty() else float(r["alone"]) + dt
	if float(r["alone"]) > FORGET:
		r["harpoon"] = {}
		r["short"] = {}
		r["next_at"] = now + FIRST
		if e.pos().distance_to(center()) > 1.0:
			_walk(sim, e, center(), dt)
		return
	if here.is_empty() or mode != "idle" or not (r["harpoon"] as Dictionary).is_empty():
		return
	var u := here[0]
	if absf(u.x - e.x) > 0.5:
		e.face = -1 if u.x < e.x else 1
	e.cooldown -= dt
	if now >= float(r["next_at"]):
		var ph := phase_of(e)
		var rot: Array = ROTATION[ph]
		var p: String = rot[int(r["idx"]) % rot.size()]
		r["idx"] = int(r["idx"]) + 1
		_start(sim, e, r, p, here, now)
		return
	if Combat.dist(e, u) <= STRIKE["reach"] and e.cooldown <= 0.0:
		e.cooldown = STRIKE["cd"]
		e.attack_started = now
		r["strike_at"] = now + STRIKE["hit"]
		r["strike_aim"] = u.pos()
		_go(r, "strike", STRIKE["time"])
		return
	if Combat.dist(e, u) > STRIKE["reach"] * 0.8:
		_go(r, "idle", 0.0)
		_walk(sim, e, u.pos(), dt)
		r["walking_at"] = now


static func _start(sim: Simulation, e: Enemy, r: Dictionary, p: String, here: Array[Unit], now: float) -> void:
	var rest: float = REST[phase_of(e)]
	match p:
		"short":
			# Sans eau, pas de court-circuit : il rouvre une vanne.
			if not wet():
				_start(sim, e, r, "vanne", here, now)
				return
			r["short"] = {"at": now, "live": now + SHORT["warn"], "until": now + SHORT["warn"] + SHORT["time"], "next": now + SHORT["warn"]}
			e.cast_started = now
			_go(r, "short", 0.75)
			sim.say(QUOTE_SHORT, 3.0)
			Sfx.at("arbalestrie_indra", e.x, e.z)
			r["next_at"] = now + SHORT["warn"] + SHORT["time"] + rest
		"harpoon":
			var u := _harpoon_target(sim, e, r, here)
			if u == null:
				r["next_at"] = now + rest
				return
			e.face = -1 if u.x < e.x else 1
			e.attack_started = now
			r["harpoon"] = {"u": u, "stage": "warn", "at": now, "head": e.pos(), "hits": 0}
			_go(r, "harpoon", HARPOON["warn"] + 0.1)
			r["next_at"] = now + HARPOON["warn"] + HARPOON["max"] + rest
		_:
			e.cast_started = now
			r["splashed"] = false
			_go(r, "vanne", VANNE["time"])
			r["next_at"] = now + VANNE["time"] + rest
			Sfx.at("fleche_impact", e.x, e.z)


## Quart rouvert par les vannes : un quart sec de préférence (celui de l'Exilé s'il y est), sinon un au hasard.
static func _flood(sim: Simulation, r: Dictionary, here: Array[Unit]) -> void:
	var open: Array = (r["quarters"] as Array).filter(func(q: Dictionary) -> bool: return not q["door"])
	if open.is_empty():
		return
	var dry: Array = open.filter(func(q: Dictionary) -> bool: return not q["flooded"])
	var pick: Dictionary = {}
	for u: Unit in here:
		if u.role == "engineer":
			var q := quarter_at(u.pos())
			if not q.is_empty() and dry.has(q):
				pick = q
	if pick.is_empty():
		var pool: Array = dry if not dry.is_empty() else open
		pick = pool[sim.rng.randi() % pool.size()]
	pick["flooded"] = true
	var c: Vector2 = (pick["rect"] as Rect2).get_center()
	Combat.zone(c.x, c.y, 5.0, Color("#3a8a9a"))
	Sfx.at("portail", c.x, c.y)


## Cible du harpon : un adepte aux pompes (une fois sur HARPOON.pumper s'il y en a), sinon l'unité la plus lointaine.
static func _harpoon_target(sim: Simulation, e: Enemy, r: Dictionary, here: Array[Unit]) -> Unit:
	var pumpers: Array[Unit] = []
	for q: Dictionary in r["quarters"]:
		if q["manned"]:
			for u: Unit in here:
				if sim.is_adept(u) and u.pos().distance_to(q["pump"]) <= PUMP_R:
					pumpers.append(u)
	if not pumpers.is_empty() and sim.rng.randf() < HARPOON["pumper"]:
		return pumpers[sim.rng.randi() % pumpers.size()]
	for i in range(here.size() - 1, -1, -1):
		if Combat.dist(e, here[i]) <= HARPOON["range"] and Combat.dist(e, here[i]) > STRIKE["reach"] + 1.0:
			return here[i]
	return null


static func _harpoon_tick(sim: Simulation, e: Enemy, r: Dictionary, now: float, dt: float) -> void:
	var h: Dictionary = r["harpoon"]
	if h.is_empty():
		return
	var u: Unit = h["u"]
	match String(h["stage"]):
		"warn":
			if now >= float(h["at"]) + HARPOON["warn"]:
				h["stage"] = "fly"
				Sfx.at("fleche_impact", e.x, e.z)
		"fly":
			if u == null or not u.alive() or u.hidden:
				r["harpoon"] = {}
				return
			var head: Vector2 = h["head"]
			var to := u.pos()
			head = head.move_toward(to, HARPOON["speed"] * dt)
			h["head"] = head
			if head.distance_to(to) < 0.3:
				h["stage"] = "pull"
				h["pull_at"] = now
				Combat.flash(u.x, u.z, Color("#ddb457"))
		"pull":
			if u == null or not u.alive() or u.hidden:
				r["harpoon"] = {}
				return
			var d := e.pos() - u.pos()
			if d.length() <= STRIKE["reach"]:
				sim.combat.damage(u, Combat.after_armor(u, HARPOON["damage"] * Biomes.power_at(e.z)) if u.role != "engineer" else Combat.boss_shot(e.z))
				u.stunned_until = now + HARPOON["stun"]
				Combat.flash(u.x, u.z, Color("#e17b63"))
				e.attack_started = now
				r["harpoon"] = {}
				return
			if now - float(h["pull_at"]) > HARPOON["max"]:
				r["harpoon"] = {}
				return
			var p := u.pos() + d.normalized() * minf(d.length() - STRIKE["reach"] * 0.8, HARPOON["pull"] * dt)
			if sim.state().walkable(p.x, p.y):
				u.x = p.x
				u.z = p.y
			u.tx = u.x
			u.tz = u.z
			u.force_move = false
			h["head"] = u.pos()
		"broken":
			if now >= float(h["at"]) + HARPOON["broken"]:
				r["harpoon"] = {}


## Une balle de l'Exilé (from → end) passe sur la chaîne tendue : trois touches la brisent.
static func chain_shot(from: Vector2, end: Vector2) -> void:
	var r := run()
	if r.is_empty():
		return
	var h: Dictionary = r.get("harpoon", {})
	if h.is_empty() or String(h["stage"]) not in ["fly", "pull"]:
		return
	var e := boss()
	var a := e.pos()
	var b: Vector2 = h["head"]
	var p := Geometry2D.get_closest_points_between_segments(from, end, a, b)
	if (p[0] as Vector2).distance_to(p[1]) > HARPOON["chain_r"]:
		return
	h["hits"] = int(h["hits"]) + 1
	Combat.flash(p[1].x, p[1].y, Color("#ddb457"))
	Sfx.at("bouclier_dore", p[1].x, p[1].y)
	if int(h["hits"]) >= HARPOON["breaks"]:
		h["stage"] = "broken"
		h["at"] = GameState.sim_time
		h["break_at"] = p[1]


## Court-circuit : l'eau électrisée frappe tout ce qui s'y trouve, toutes les SHORT.every s.
static func _short_tick(sim: Simulation, e: Enemy, r: Dictionary, now: float) -> void:
	var s: Dictionary = r["short"]
	if s.is_empty():
		return
	if now >= float(s["until"]):
		r["short"] = {}
		return
	if now < float(s["live"]) or now < float(s["next"]):
		return
	s["next"] = float(s["next"]) + SHORT["every"]
	var amount: float = SHORT["dps"] * SHORT["every"] * Biomes.power_at(e.z)
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and water_at(u.x, u.z) >= WET:
			sim.combat.damage(u, amount)
			Combat.flash(u.x, u.z, Color("#cfe8ff"))
	for q: Dictionary in r["quarters"]:
		var eel: Enemy = q["eel"]
		if eel != null and eel.hp > 0.0 and not eel.hidden:
			sim.combat.damage(eel, amount)


static func _strike_tick(sim: Simulation, e: Enemy, r: Dictionary, here: Array[Unit], now: float) -> void:
	if now < float(r["strike_at"]):
		return
	r["strike_at"] = INF
	var at := e.pos() + Vector2(e.face * 1.6, 0.0)
	Combat.zone(at.x, at.y, STRIKE["reach"], Color("#ddb457"))
	for u: Unit in here:
		if u.pos().distance_to(at) <= STRIKE["reach"] + 0.6:
			sim.combat.damage(u, Combat.after_armor(u, e.damage) if u.role != "engineer" else Combat.boss_shot(e.z))
			Combat.flash(u.x, u.z, Color("#e17b63"))


static func _walk(sim: Simulation, e: Enemy, goal: Vector2, dt: float) -> void:
	var next := sim.steer(e, goal)
	var p := e.pos() + (next - e.pos()).limit_length(e.speed * dt)
	if in_room(p) and sim.state().walkable(p.x, p.y):
		if absf(p.x - e.x) > 0.01:
			e.face = -1 if p.x < e.x else 1
		e.x = p.x
		e.z = p.y


## Il marche (rendu : animation de marche) : pas fait il y a moins de 0,15 s.
static func walking() -> bool:
	return GameState.sim_time - float(run().get("walking_at", -INF)) < 0.15


## Objectif affiché tant qu'il est éveillé (Quests.objective), sinon {}.
static func objective() -> Dictionary:
	if not active():
		return {}
	var e := boss()
	return {"id": "eclusier", "quest": "L’Éclusier de Byrsa", "interrupt": true,
		"label": "Abattre l’Éclusier de Byrsa" + ("" if not wet() else " · tenir les pompes"),
		"quote": "", "done_quote": "",
		"value": "%d PV" % ceili(e.hp), "progress": 1.0 - e.hp / e.max_hp}
