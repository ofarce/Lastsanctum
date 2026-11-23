class_name Archipretre
extends RefCounted
## L'Archiprêtre aux racines : mini-boss 1 du Temple (planches/mini-boss-temple-veines-propositions.html, T1 validé
## le 2026-11-22 ; dessin : planches/archipretre-racines-rendu.html, silhouette A « Agenouillé, soudé à l'autel »,
## atlas assets/imported/archipretre/ exportés par tools/archipretre/export.py).
##
## Un prêtre du Temple soudé par les racines de la Bête à l'autel de l'Oratoire envahi, l'arène du quartier A (salle
## « mb1 » du plan, RoomLayout). Il dort, invisible, jusqu'à ce qu'un allié entre dans la salle, puis ne quitte plus
## l'autel. On le combat avec l'escouade : tout le monde peut le blesser (armure, Catalog.ENEMY).
## - Racines : trois lignes annoncées au sol filent de l'autel vers les unités les plus proches ; à l'arrivée elles
##   blessent et immobilisent ROOT.stun secondes.
## - Nappe : la corruption s'étend de l'autel par vagues et retire des PV à l'Exilé ; les esprits y sont immunisés.
## - Phase II (moitié des PV) : trois chiens de la Bête jaillissent du bulbe toutes les CALL.every secondes.
## - Canaliser : quatre places de prière (une par culte). Un esprit de chaque culte debout sur la sienne : la nappe
##   recule et le bulbe s'ouvre ; les dégâts reçus sont doublés (OPEN_MULT).
## - Sa chute ouvre la porte « mb1 » vers le quartier B (RoomEncounters.open_door) et allume le portail de retour de
##   l'arène (PortalNet). Il lâche le plan de la Lanterne de Medeina et la Clef de la Nef dorée (Loot).
## État : GameState.archipretre = {state, seed, e, room, center, altar, places, mode, t0, until, phase, open, nappe,
## roots, next_root, next_call, alone, burn}. Rendu : world/archipretre/archipretre_view.gd et archipretre_marks.gd.
## Chiffres de départ proposés par moi (planche), à régler.

const KIND := "archipretre"
## Silhouette au sol (unités ; 8 px natifs par unité) : robe de 28 px, 50 px de haut avec le bulbe.
const BODY := {"half_w": 1.9, "top": 6.2, "foot": 0.6, "melee": 1.6}
const OPEN_MULT := 2.0
const PHASE_HP := 0.5
const PHASE_NAMES := ["I · Les racines", "II · La meute"]
## Repos entre deux salves de racines, par phase (s).
const REST := [3.4, 2.6]
## Racines : nombre, annonce (s), longueur (u), demi-largeur touchée (u), dégâts, immobilisation (s).
const ROOT := {"count": 3, "warn": 1.1, "length": 30.0, "width": 1.6, "damage": 16.0, "stun": 1.5}
## Nappe : rayon qui respire entre min et max (u), période (s), dégâts par seconde à l'Exilé, vitesse de retrait.
const NAPPE := {"min": 8.0, "max": 22.0, "period": 7.0, "dps": 4.0, "ease": 2.5}
## Meute de phase II : chiens par appel, intervalle (s).
const CALL := {"count": 3, "every": 25.0, "first": 3.0}
## Places de prière : décalage depuis l'Archiprêtre (u), rayon où un esprit tient sa place.
const PLACES := {"sigil": Vector2(-14.0, -4.0), "aether": Vector2(-20.0, 8.0), "indra": Vector2(20.0, 8.0), "medeina": Vector2(0.0, 18.0)}
const PLACE_R := 3.0
## Sans personne dans la salle pendant ce délai, il se tait (il reste éveillé, sans regagner ses PV).
const FORGET := 8.0

const QUOTE_WAKE := "Un prêtre du Temple… les racines de la Bête l’ont cousu à l’autel. Il faut les quatre cultes pour l’en arracher."
const QUOTE_OPEN := "Les quatre cultes prient : le bulbe s’ouvre !"
const QUOTE_DONE := "L’Archiprêtre s’effondre. La porte de la Nef dorée s’ouvre."


static func run() -> Dictionary:
	return GameState.archipretre


static func boss() -> Enemy:
	return GameState.archipretre.get("e")


## En combat : éveillé et vivant (barre de boss, pas de sauvegarde).
static func active() -> bool:
	var e := boss()
	return e != null and e.hp > 0.0 and String(GameState.archipretre.get("mode", "sleep")) != "sleep"


static func center() -> Vector2:
	return GameState.archipretre.get("center", Vector2.ZERO)


static func phase_of(e: Enemy) -> int:
	return 1 if e.hp <= e.max_hp * PHASE_HP else 0


## Bulbe ouvert : les quatre places tenues.
static func bulb_open() -> bool:
	return bool(GameState.archipretre.get("open", false))


## Dégâts reçus : doublés bulbe ouvert (Combat.damage).
static func damage_mult() -> float:
	return OPEN_MULT if bulb_open() else 1.0


## Arène de l'Archiprêtre dans le plan du Temple (salle du mini-boss 1, quartier A), ou {} sans plan.
static func arena_room(st: TerrainState) -> Dictionary:
	if st == null or st.temple_layout.is_empty():
		return {}
	for room: Dictionary in st.temple_layout["rooms"]:
		if room["role"] == "mb1":
			return room
	return {}


static func in_room(p: Vector2) -> bool:
	var rr: Rect2i = run().get("rect", Rect2i())
	return rr.has_point(Vector2i(floori(p.x / 4.0), floori(p.y / 4.0)))


## Un esprit du culte `cult` tient la place `at`.
static func _held(cult: String, at: Vector2) -> bool:
	for u: Unit in GameState.units:
		if u.role == cult and u.alive() and not u.hidden and u.pos().distance_to(at) <= PLACE_R:
			return true
	return false


## Cultes dont la place est tenue (rendu des places, bulbe).
static func held_cults() -> Array:
	var out := []
	for cult: String in run().get("places", {}):
		if _held(cult, run()["places"][cult]):
			out.append(cult)
	return out


static func tick(sim: Simulation) -> void:
	if GameState.ended or sim.world == null:
		return
	var st := sim.state()
	var room := arena_room(st)
	if room.is_empty():
		return
	var r := GameState.archipretre
	if r.get("state") != st or r.get("seed") != st.seed:
		_setup(st, r, room)
	var e := boss()
	if e != null and e.hp <= 0.0 and String(r["mode"]) != "dead":
		r["mode"] = "dead"
		r["open"] = false
		(r["roots"] as Array).clear()
		RoomEncounters.open_door(sim, "mb1")
		sim.say(QUOTE_DONE, 4.0)


static func _setup(st: TerrainState, r: Dictionary, room: Dictionary) -> void:
	r.clear()
	r["state"] = st
	r["seed"] = st.seed
	var rr: Rect2i = room["rect"]
	r["rect"] = rr
	r["room"] = room["id"]
	# Autel au nord de la salle, l'Archiprêtre agenouillé devant.
	var cx := rr.position.x * 4.0 + rr.size.x * 2.0
	var altar := Vector2(cx, rr.position.y * 4.0 + 8.0)
	var c := Vector2(cx, altar.y + 7.0)
	r["altar"] = altar
	r["center"] = c
	var places := {}
	var lo := Vector2(rr.position.x * 4.0 + 4.0, rr.position.y * 4.0 + 4.0)
	var hi := Vector2(rr.end.x * 4.0 - 4.0, rr.end.y * 4.0 - 4.0)
	for cult: String in PLACES:
		var p := (c + (PLACES[cult] as Vector2)).clamp(lo, hi)
		places[cult] = p if st.is_gallery(p.x, p.y) else st.push_out_of_rock(p)
	r["places"] = places
	r["mode"] = "sleep"
	r["phase"] = 0
	r["open"] = false
	r["nappe"] = 0.0
	r["roots"] = []
	r["next_root"] = INF
	r["next_call"] = INF
	r["alone"] = 0.0
	r["burn"] = 0.0
	var e := Enemy.make(KIND, c.x, c.y, 0.0)
	e.beast = true
	e.hidden = true
	r["e"] = e
	GameState.enemies.append(e)


static func _go(r: Dictionary, mode: String, seconds: float) -> void:
	r["mode"] = mode
	r["t0"] = GameState.sim_time
	r["until"] = GameState.sim_time + seconds


## Unités visibles dans l'arène, de la plus proche à la plus lointaine.
static func _in_arena(e: Enemy, alive: Array[Unit]) -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in alive:
		if not u.hidden and in_room(u.pos()):
			out.append(u)
	out.sort_custom(func(a: Unit, b: Unit) -> bool: return a.pos().distance_squared_to(e.pos()) < b.pos().distance_squared_to(e.pos()))
	return out


## Conduite du boss, appelée par Combat.update_enemies à la place de la conduite normale.
static func act(sim: Simulation, e: Enemy, dt: float, alive: Array[Unit]) -> void:
	var r := run()
	if r.is_empty() or r.get("e") != e:
		return
	var now := GameState.sim_time
	var here := _in_arena(e, alive)
	if String(r["mode"]) == "sleep":
		if here.is_empty():
			return
		e.hidden = false
		_go(r, "idle", 1.5)
		r["next_root"] = now + 2.0
		sim.say(QUOTE_WAKE, 5.0)
		Sfx.at("vague", e.x, e.z)
		Combat.zone(e.x, e.z, 4.0, Color("#a8202e"))
		return
	r["alone"] = 0.0 if not here.is_empty() else float(r["alone"]) + dt
	var phase := phase_of(e)
	if phase != int(r["phase"]):
		r["phase"] = phase
		r["next_call"] = now + float(CALL["first"])
		sim.say("Le bulbe se fend : la meute de la Bête en sort !", 3.0)
	if not here.is_empty() and absf(here[0].x - e.x) > 0.5:
		e.face = -1 if here[0].x < e.x else 1
	# Canalisation : les quatre places tenues.
	var was_open := bulb_open()
	r["open"] = held_cults().size() == PLACES.size()
	if bulb_open() and not was_open:
		sim.say(QUOTE_OPEN, 3.0)
		Combat.zone(e.x, e.z - 5.0, 3.0, Color("#ffe08a"))
	_nappe(sim, r, alive, now, dt)
	_land_roots(sim, r, alive, now)
	if float(r["alone"]) > FORGET:
		return
	# Racines : une salve, puis un repos.
	if now >= float(r["next_root"]) and not here.is_empty():
		_cast_roots(r, e, here, now)
		_go(r, "cast", float(ROOT["warn"]))
		r["next_root"] = now + float(ROOT["warn"]) + float(REST[phase])
	elif String(r["mode"]) == "cast" and now >= float(r["until"]):
		_go(r, "idle", 0.0)
	# Meute de phase II.
	if phase == 1 and now >= float(r["next_call"]):
		r["next_call"] = now + float(CALL["every"])
		_call_pack(sim, e)


## La nappe respire entre NAPPE.min et NAPPE.max ; bulbe ouvert, elle se retire. Elle brûle l'Exilé qui y entre.
static func _nappe(sim: Simulation, r: Dictionary, alive: Array[Unit], now: float, dt: float) -> void:
	var breath := 0.5 + 0.5 * sin(now * TAU / float(NAPPE["period"]))
	var goal := 0.0 if bulb_open() else lerpf(float(NAPPE["min"]), float(NAPPE["max"]), breath)
	r["nappe"] = move_toward(float(r["nappe"]), goal, float(NAPPE["max"]) * dt / float(NAPPE["ease"]))
	var c := center()
	for u: Unit in alive:
		if u.role != "engineer" or u.hidden or u.pos().distance_to(c) > float(r["nappe"]):
			continue
		var acc := float(r["burn"]) + dt * float(NAPPE["dps"])
		while acc >= 1.0:
			acc -= 1.0
			sim.combat.damage(u, 1.0)
		r["burn"] = acc


## Une salve : une racine vers chacune des unités les plus proches (au plus ROOT.count), annoncée au sol.
static func _cast_roots(r: Dictionary, e: Enemy, here: Array[Unit], now: float) -> void:
	var from := e.pos() + Vector2(0.0, 1.0)
	for i in mini(int(ROOT["count"]), here.size()):
		var d := (here[i].pos() - from).normalized()
		if d == Vector2.ZERO:
			d = Vector2.DOWN
		(r["roots"] as Array).append({"a": from, "b": from + d * float(ROOT["length"]), "from": now, "at": now + float(ROOT["warn"])})
	Sfx.at("vague", e.x, e.z)


## Racines arrivées à terme : elles blessent et immobilisent ce qui se tient sur leur ligne.
static func _land_roots(sim: Simulation, r: Dictionary, alive: Array[Unit], now: float) -> void:
	var roots: Array = r["roots"]
	for i in range(roots.size() - 1, -1, -1):
		var m: Dictionary = roots[i]
		if now < float(m["at"]):
			continue
		if now > float(m["at"]) + 0.5:
			roots.remove_at(i)
			continue
		if m.get("hit", false):
			continue
		m["hit"] = true
		for u: Unit in alive:
			if u.hidden:
				continue
			var p := Geometry2D.get_closest_point_to_segment(u.pos(), m["a"], m["b"])
			if p.distance_to(u.pos()) <= float(ROOT["width"]):
				sim.combat.damage(u, Combat.after_armor(u, ROOT["damage"]))
				u.stunned_until = maxf(u.stunned_until, now + float(ROOT["stun"]))
				Combat.flash(u.x, u.z, Color("#7e5648"))


## Trois chiens de la Bête jaillissent du bulbe, hors vague, à la menace du Temple.
static func _call_pack(sim: Simulation, e: Enemy) -> void:
	var st := sim.state()
	var stats := Catalog.menace_stats(Catalog.menace_tier(GameState.menace) + Biomes.threat_tiers(int(Biomes.LIST[0]["threat"])), true)
	for k in int(CALL["count"]):
		var at := st.push_out_of_rock(e.pos() + Vector2.from_angle(PI * (0.25 + 0.25 * k)) * 4.0)
		var d := Enemy.make("beast", at.x, at.y, 0.6 + 0.2 * k, stats)
		d.beast = true
		GameState.enemies.append(d)
	Combat.zone(e.x, e.z - 4.0, 4.0, Color("#a8202e"))
	Sfx.at("vague", e.x, e.z)


## Objectif affiché tant qu'il est éveillé (Quests.objective), sinon {}.
static func objective() -> Dictionary:
	if not active():
		return {}
	var e := boss()
	return {"id": "archipretre", "quest": "L’Archiprêtre aux racines", "interrupt": true,
		"label": "Canaliser les quatre cultes et abattre l’Archiprêtre",
		"quote": "", "done_quote": "",
		"value": "%d PV" % ceili(e.hp), "progress": 1.0 - e.hp / e.max_hp}
