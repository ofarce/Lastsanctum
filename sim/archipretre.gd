class_name Archipretre
extends RefCounted
## L'Archiprêtre aux racines : mini-boss 1 du Temple (planches/mini-boss-temple-veines-propositions.html, T1 validé
## le 2026-11-22 ; dessin : planches/archipretre-racines-rendu.html, silhouette A « Agenouillé, soudé à l'autel »,
## atlas assets/imported/archipretre/ exportés par tools/archipretre/export.py).
##
## Un prêtre du Temple soudé par les racines de la Bête à l'autel de l'Oratoire envahi, l'arène du quartier A (salle
## « mb1 » du plan, RoomLayout). Il dort, invisible, jusqu'à ce qu'un allié entre dans la salle, puis ne quitte plus
## l'autel. On le combat avec l'escouade : tout le monde peut le blesser (armure, Catalog.ENEMY).
## Attaques (2026-11-23, à la place des racines, de la nappe, de la meute et de la canalisation des quatre cultes) :
## celles de la phase II de l'Œil de la Matrice, que le joueur retrouvera chez le boss. Il enchaîne rotation() (Regard,
## Strabisme, Pupilles errantes, Larmes, Cils) avec une fenêtre de souffle WINDOW entre deux, par le moteur de l'Œil
## (OeilMatrice.host_* : mêmes balles, mêmes annonces, même rendu, centrés sur lui). Il vise l'Exilé s'il est dans
## l'arène, sinon l'unité la plus proche ; les balles touchent toutes les unités de l'arène (l'Exilé : coup de boss ;
## les autres : dégâts de la balle après armure, OeilMatrice._hit). Les pupilles errantes se laissent abattre par
## tout le monde.
## - Sa chute ouvre la porte « mb1 » vers le quartier B (RoomEncounters.open_door) et allume le portail de retour de
##   l'arène (PortalNet). Il lâche le plan de la Lanterne de Medeina et la Clef de la Nef dorée (Loot).
## État : GameState.archipretre = {state, seed, e, rect, room, center, altar, mode, t0, until, idx, next_at,
## busy_until, alone}. Rendu : world/archipretre/archipretre_view.gd ; attaques : world/oeil/oeil_fx.gd.

const KIND := "archipretre"
## Silhouette au sol (unités ; 8 px natifs par unité) : robe de 28 px, 50 px de haut avec le bulbe.
const BODY := {"half_w": 1.9, "top": 6.2, "foot": 0.6, "melee": 1.6}
## Une seule phase : la phase II de l'Œil (nom pour la barre de boss).
const PHASE_NAMES := ["L’iris"]
## Attaques de la phase II de l'Œil, dans son ordre.
static func rotation() -> Array:
	return OeilMatrice.ROTATION[OeilMatrice.HOST_PHASE]


## Délai de la première attaque à l'éveil, fenêtre de souffle entre deux (celle de l'Œil en phase II), durée du
## geste d'incantation (animation cast).
const FIRST := 2.0
const WINDOW := 1.4
const CAST := 1.1
## Sans personne dans la salle pendant ce délai, il se tait (il reste éveillé, sans regagner ses PV).
const FORGET := 8.0

const QUOTE_WAKE := "Un prêtre du Temple… les racines de la Bête l’ont cousu à l’autel, et c’est l’Œil qui regarde à travers lui."
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


static func phase_of(_e: Enemy) -> int:
	return 0


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


## (x, z) est dans l'arène, hors de la roche (grow : marge en unités) : là où volent les balles.
static func in_arena(x: float, z: float, grow := 0.0) -> bool:
	var r := run()
	var rr: Rect2i = r.get("rect", Rect2i())
	if not Rect2(rr.position * 4.0, rr.size * 4.0).grow(grow).has_point(Vector2(x, z)):
		return false
	var st: TerrainState = r.get("state")
	return st != null and st.is_gallery(x, z)


## Unités visibles dans l'arène : les cibles des balles.
static func squad() -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and in_room(u.pos()):
			out.append(u)
	return out


## L'Exilé dans l'arène, ou null : la cible visée en premier.
static func exile() -> Unit:
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden and in_room(u.pos()):
			return u
	return null


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
		r["down_at"] = GameState.sim_time
		if OeilMatrice.hosted():
			OeilMatrice.host_clear(true)
		RoomEncounters.open_door(sim, "mb1")
		sim.say(QUOTE_DONE, 4.0)
		OrbitGate.guard_fell(sim)
	# Les éclats de ses balles finissent de s'éteindre, puis le moteur de l'Œil est rendu.
	if String(r["mode"]) == "dead" and GameState.oeil_host == KIND:
		OeilMatrice.host_tick(sim, null, GameState.sim_time, 0.0)
		if GameState.oeil_fx.is_empty():
			OeilMatrice.host_end()


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
	r["mode"] = "sleep"
	r["idx"] = 0
	r["next_at"] = INF
	r["busy_until"] = -INF
	r["alone"] = 0.0
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
		r["next_at"] = now + FIRST
		OeilMatrice.host_begin(KIND)
		sim.say(QUOTE_WAKE, 5.0)
		Sfx.at("vague", e.x, e.z)
		Combat.zone(e.x, e.z, 4.0, Color("#a8202e"))
		return
	# Cible visée : l'Exilé s'il est là, sinon l'unité la plus proche.
	var u := exile()
	if u == null and not here.is_empty():
		u = here[0]
	if u != null and absf(u.x - e.x) > 0.5:
		e.face = -1 if u.x < e.x else 1
	if GameState.oeil_host == KIND:
		OeilMatrice.host_tick(sim, u, now, dt)
	if String(r["mode"]) == "cast" and now >= float(r["until"]):
		_go(r, "idle", 0.0)
	# Salle vide : il se tait, ses balles s'éteignent.
	r["alone"] = 0.0 if u != null else float(r["alone"]) + dt
	if float(r["alone"]) > FORGET:
		if not GameState.oeil_bullets.is_empty() or not GameState.oeil_fx.is_empty():
			OeilMatrice.host_clear(false)
		r["busy_until"] = -INF
		r["next_at"] = now + FIRST
		return
	# Attaque suivante de la rotation, puis fenêtre de souffle.
	if u != null and GameState.oeil_host == KIND and now >= float(r["next_at"]) and now >= float(r["busy_until"]):
		var p: String = rotation()[int(r["idx"]) % rotation().size()]
		r["idx"] = int(r["idx"]) + 1
		var end := OeilMatrice.host_cast(sim, u, p, now)
		_go(r, "cast", minf(end - now, CAST))
		r["busy_until"] = end
		r["next_at"] = end + WINDOW
		Sfx.at("vague", e.x, e.z)


## Objectif affiché tant qu'il est éveillé (Quests.objective), sinon {}.
static func objective() -> Dictionary:
	if not active():
		return {}
	var e := boss()
	return {"id": "archipretre", "quest": "L’Archiprêtre aux racines", "interrupt": true,
		"label": "Abattre l’Archiprêtre aux racines",
		"quote": "", "done_quote": "",
		"value": "%d PV" % ceili(e.hp), "progress": 1.0 - e.hp / e.max_hp}
