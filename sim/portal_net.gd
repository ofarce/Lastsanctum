class_name PortalNet
extends RefCounted
## Réseau des portails de Merenor (planches/portails-pylones-propositions.html, choix du 2026-11-22) :
## portail « Orbe suspendu », annonce du reflux cumulant les quatre propositions (glyphes qui virent, nappe qui
## ressort, rayons qui faiblissent, fêlure au seuil), carte des portails pour choisir la destination, sortie
## de la meute sur place.
##
## - Un pylône canalisé (Pylons, les quatre cultes prient) est un portail vers tout autre portail ouvert ;
##   l'Ancre en est un, toujours ouvert. Le seuil est devant la face sud du socle (Pylons.BLESS_SPOT).
## - L'Exilé incarné, sur un seuil, appuie sur E : la carte des portails s'ouvre (MinimapOverlay), un clic
##   sur une destination l'y envoie. Les adeptes et les unités prennent les portails d'eux-mêmes quand le
##   trajet y gagne nettement (route, appelé par Simulation.steer).
## - Pas de voyage avec un ennemi à moins de SAFE unités, ni en duel de boss, ni vers ou depuis un pylône en
##   reflux.
## - Reflux : un seul à la fois dans tout le réseau, environ un tous les GAP par pylône canalisé, jamais
##   pendant la vague de jour. Annonce de WARN secondes (bannière, minuteur), puis la meute de Merenor sort
##   par le seuil et vise les esprits qui prient ; au bout de OUT secondes le pylône revient à la normale,
##   la meute reste. Un esprit tué casse la canalisation (Pylons), ce qui arrête le reflux.

const ANCHOR_ID := -1
## Seuil de l'Ancre : au sud de son socle (jusqu'à z −152,4), hors de portée de la prière à l'Ancre
## (Capsule.ANCHOR_REACH = 7), où E sert déjà.
const ANCHOR_THRESHOLD := Vector2(0.0, 9.5)
## L'Exilé ouvre la carte avec E à cette distance du seuil ou moins.
const REACH := 2.4
## Une unité en route par un portail part quand elle arrive à cette distance du seuil.
const ARRIVE := 1.2
## Voyage (secondes) : la bulle gonfle et se referme (DEPART), l'orbe remonte le rayon (TRANSIT), puis le
## voyageur ressort de la bulle au seuil d'arrivée (LAND). Planche, modèle 5 : k de 0 à 1 au départ.
const DEPART := 0.9
const TRANSIT := 0.5
const LAND := 0.9
## Pas de portail en deçà de cette distance à vol d'oiseau ; le détour doit faire gagner au moins 30 %.
const ROUTE_MIN := 48.0
const ROUTE_GAIN := 0.7
## Coût d'un passage (unités de marche équivalentes).
const WARP_COST := 12.0
## Rayon dans lequel un ennemi empêche de voyager (unités).
const SAFE := 12.0
## Reflux : annonce, durée de la sortie, intervalle par pylône canalisé (deux journées), report si une vague
## est en cours, meute (comme les meutes de nuit, un peu plus petite).
const WARN := 60.0
const OUT := 20.0
const GAP := 2.0 * DayNight.LENGTH
const GAP_JITTER := 0.3
const WAVE_DELAY := 30.0
const PACK := {"base": 3, "per_tier": 1, "cap": 10}

## Destination choisie dans la carte (id du nœud de départ quand la carte est ouverte depuis un seuil, sinon
## NO_MAP).
const NO_MAP := -999
static var map_from := NO_MAP


# ---------------------------------------------------------------- Nœuds

## Seuil d'un pylône : devant la face sud du socle, sur du sol praticable.
static func threshold(st: TerrainState, p: Dictionary) -> Vector2:
	if p.has("threshold"):
		return p["threshold"]
	var at := Vector2(p["x"], p["z"]) + Pylons.BLESS_SPOT
	if st != null and not st.walkable(at.x, at.y):
		at = st.push_out_of_rock(at)
	p["threshold"] = at
	return at


static func anchor_threshold() -> Vector2:
	return CaveShape.CORE + ANCHOR_THRESHOLD


## Pylône éveillé et canalisé (portail possible, ouvert ou en reflux).
static func linked(p: Dictionary) -> bool:
	return bool(p.get("active", false)) and p.has("slots") and bool(p.get("channeled", false))


## Pylône canalisé sans reflux : le portail est ouvert.
static func pylon_open(p: Dictionary) -> bool:
	return linked(p) and not p.has("reflux")


## Nom d'un pylône : numéro d'éveil et biome.
static func pylon_name(st: TerrainState, p: Dictionary) -> String:
	var n := 1
	for q: Dictionary in st.portals:
		if q == p:
			break
		if q.get("active", false):
			n += 1
	return "Pylône %d · %s" % [n, Biomes.LIST[Biomes.index_at(float(p["z"]))]["name"]]


## Portails fixes des salles (biomes en salles, choix du 2026-11-22) : hub, antichambre, arènes des mini-boss et
## portail de C. Allumés pour de bon à la première visite d'un allié (les arènes aussi, en attendant que les
## mini-boss y soient : elles s'ouvriront alors à leur mort). Identifiant de nœud : ROOM_ID0 + id de salle.
const ROOM_ID0 := 10000
const ROOM_LABEL := {"hub": "Hub", "antechamber": "Antichambre", "threshold": "Portail", "mb1": "Arène", "mb2": "Arène"}
## Noms des quartiers du Temple (planches/quartiers-entrees-propositions.html, validés le 2026-11-22).
const TEMPLE_QUARTERS := {"A": "Les Cloîtres", "B": "La Nef dorée", "C": "Les Racines", "R": "L’Orbite"}


## Seuil du portail d'une salle : au centre (dans une arène, vers son entrée sud, loin du futur mini-boss).
static func room_threshold(st: TerrainState, room: Dictionary) -> Vector2:
	if room.has("threshold"):
		return room["threshold"]
	var rr: Rect2i = room["rect"]
	var at := Vector2(rr.position.x * 4.0 + rr.size.x * 2.0, rr.position.y * 4.0 + rr.size.y * 2.0)
	if room["kind"] == "miniboss":
		at.y += rr.size.y * 1.2
	if st != null and not st.walkable(at.x, at.y):
		at = st.push_out_of_rock(at)
	room["threshold"] = at
	return at


static func room_name(room: Dictionary) -> String:
	return "%s · %s" % [ROOM_LABEL.get(room["role"], "Portail"), TEMPLE_QUARTERS.get(room["quarter"], "")]


## Nœuds du réseau : l'Ancre, les pylônes canalisés, puis les portails de salle allumés.
## {id, pos (seuil), pylon (ou vide), name, open}. Sans autre portail, pas de réseau : le portail de l'Ancre
## n'apparaît qu'avec le premier.
static func nodes(st: TerrainState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if st == null:
		return out
	for p: Dictionary in st.portals:
		if linked(p):
			out.append({"id": int(p["id"]), "pos": threshold(st, p), "pylon": p, "name": pylon_name(st, p), "open": pylon_open(p)})
	if not st.temple_layout.is_empty() and not GameState.room_portals.is_empty():
		for room: Dictionary in st.temple_layout["rooms"]:
			if room["portal"] and GameState.room_portals.has(room["id"]):
				out.append({"id": ROOM_ID0 + int(room["id"]), "pos": room_threshold(st, room), "pylon": {}, "name": room_name(room), "open": true})
	if not out.is_empty():
		out.push_front({"id": ANCHOR_ID, "pos": anchor_threshold(), "pylon": {}, "name": "Ancre", "open": true})
	return out


static func open_nodes(st: TerrainState) -> Array[Dictionary]:
	return nodes(st).filter(func(n: Dictionary) -> bool: return n["open"])


static func node(st: TerrainState, id: int) -> Dictionary:
	for n in nodes(st):
		if int(n["id"]) == id:
			return n
	return {}


## Nœud ouvert dont le seuil est à `r` unités de `at` ou moins (le plus proche), ou vide.
static func node_at(st: TerrainState, at: Vector2, r := REACH) -> Dictionary:
	var best := {}
	var bd := r
	for n in open_nodes(st):
		var d := at.distance_to(n["pos"])
		if d <= bd:
			bd = d
			best = n
	return best


static func _nearest(list: Array[Dictionary], at: Vector2) -> Dictionary:
	var best := {}
	var bd := INF
	for n in list:
		var d := at.distance_to(n["pos"])
		if d < bd:
			bd = d
			best = n
	return best


## Un ennemi vivant à moins de SAFE unités, ou un duel de boss : on ne voyage pas.
static func danger(u: Unit) -> bool:
	if Simulation.in_boss_fight(u):
		return true
	for e: Variant in GameState.enemies:
		if e.hp > 0.0 and not e.hidden and not e.dead and Combat.hyp(e.x - u.x, e.z - u.z) < SAFE:
			return true
	return false


# ---------------------------------------------------------------- Voyage

static func warping(u: Unit) -> bool:
	return u.memo.has("warp")


## Point visé par une unité en route : le seuil du portail d'entrée quand le détour par le réseau fait gagner
## nettement sur la marche, sinon null (marche ordinaire). Lance le voyage au seuil.
static func route(sim: Simulation, u: Unit, to: Vector2) -> Variant:
	if u is Enemy or u.hidden or u == GameState.incarnated or sim.world == null:
		return null
	if warping(u):
		return u.pos()
	var d := u.pos().distance_to(to)
	if d < ROUTE_MIN:
		return null
	var open := open_nodes(sim.state())
	if open.size() < 2:
		return null
	var a := _nearest(open, u.pos())
	var b := _nearest(open, to)
	if a == b or int(a["id"]) == int(b["id"]):
		return null
	var via: float = u.pos().distance_to(a["pos"]) + (b["pos"] as Vector2).distance_to(to) + WARP_COST
	if via >= d * ROUTE_GAIN:
		return null
	if u.pos().distance_to(a["pos"]) <= ARRIVE:
		if danger(u):
			return null
		start(u, a, b)
		return u.pos()
	return a["pos"]


## Voyage de l'Exilé choisi sur la carte : il doit être au seuil d'un portail ouvert, hors combat.
static func travel(sim: Simulation, u: Unit, dest_id: int) -> bool:
	if u == null or not u.alive() or warping(u):
		return false
	var st := sim.state()
	var a := node_at(st, u.pos())
	var b := node(st, dest_id)
	if a.is_empty():
		sim.say("Placez-vous sur le seuil d’un portail ouvert pour voyager.", 2.5)
		return false
	if b.is_empty() or not b["open"]:
		sim.say("Ce portail est fermé.", 2.0)
		return false
	if int(a["id"]) == dest_id:
		return false
	if danger(u):
		sim.say("Impossible de voyager en plein combat.", 2.0)
		return false
	start(u, a, b)
	sim.say("L’Exilé passe le portail vers %s." % b["name"], 2.0)
	return true


static func start(u: Unit, a: Dictionary, b: Dictionary) -> void:
	u.memo["warp"] = {"t0": GameState.sim_time, "from": a["pos"], "to": b["pos"], "to_id": int(b["id"]), "moved": false}
	u.memo.erase("path")
	u.x = (a["pos"] as Vector2).x
	u.z = (a["pos"] as Vector2).y
	Sfx.at("portail", u.x, u.z)


## Avancement visuel du voyage : k de 0 à 1 au départ (bulle, rétrécissement, orbe qui remonte), puis de 1
## à 0 à l'arrivée ; vide hors voyage. {k, out}.
static func warp_view(u: Unit) -> Dictionary:
	if not u.memo.has("warp"):
		return {}
	var t := GameState.sim_time - float(u.memo["warp"]["t0"])
	if t < DEPART + TRANSIT:
		return {"k": t / (DEPART + TRANSIT), "out": true}
	return {"k": clampf(1.0 - (t - DEPART - TRANSIT) / LAND, 0.0, 1.0), "out": false}


static func _warp_step(sim: Simulation, u: Unit) -> void:
	var w: Dictionary = u.memo["warp"]
	var t := GameState.sim_time - float(w["t0"])
	if not w["moved"] and t >= DEPART + TRANSIT:
		var to: Vector2 = w["to"]
		u.x = to.x
		u.z = to.y
		u.memo.erase("path")
		w["moved"] = true
		if u == GameState.incarnated:
			u.tx = u.x
			u.tz = u.z
			u.force_move = false
			if sim.world != null:
				sim.world.camera.set_view(to, sim.world.camera.px)
		Sfx.at("portail", u.x, u.z)
	if t >= DEPART + TRANSIT + LAND:
		u.memo.erase("warp")


## Touche E de l'Exilé incarné : ouvre (ou ferme) la carte des portails depuis le seuil où il se tient.
static func toggle_map(sim: Simulation) -> bool:
	if map_from != NO_MAP:
		Events.portal_map.emit(NO_MAP)
		return true
	var eng := GameState.incarnated
	if eng == null or eng.role != "engineer" or not eng.alive() or eng.hidden or warping(eng):
		return false
	var n := node_at(sim.state(), eng.pos())
	if n.is_empty():
		return false
	if danger(eng):
		sim.say("Impossible de voyager en plein combat.", 2.0)
		return true
	if open_nodes(sim.state()).size() < 2:
		sim.say("Aucun autre portail ouvert : canalisez un Pylône de Merenor ou allumez le portail d’une salle.", 2.5)
		return true
	Events.portal_map.emit(int(n["id"]))
	return true


# ---------------------------------------------------------------- Reflux

## Avancement du reflux d'un pylône : de 0 à 1 pendant l'annonce, 1 pendant la sortie, 0 sinon.
static func reflux_k(p: Dictionary) -> float:
	if not p.has("reflux"):
		return 0.0
	var r: Dictionary = p["reflux"]
	if r["stage"] == "warn":
		return clampf((GameState.sim_time - float(r["at"])) / WARN, 0.0, 1.0)
	return 1.0


## Secondes avant la sortie de la meute (annonce en cours), sinon -1.
static func reflux_remaining(p: Dictionary) -> float:
	if not p.has("reflux") or p["reflux"]["stage"] != "warn":
		return -1.0
	return maxf(0.0, WARN - (GameState.sim_time - float(p["reflux"]["at"])))


## Secondes avant la fin de la sortie de la meute (étape "out"), ou -1.
static func reflux_out_remaining(p: Dictionary) -> float:
	if not p.has("reflux") or p["reflux"]["stage"] != "out":
		return -1.0
	return maxf(0.0, OUT - (GameState.sim_time - float(p["reflux"]["out_at"])))


static func tick(sim: Simulation, _dt: float) -> void:
	for u in GameState.units:
		if u.memo.has("warp"):
			_warp_step(sim, u)
	if GameState.ended or sim.world == null:
		return
	_reflux(sim)
	_light_rooms(sim)
	_announce_assault(sim)


## Portails de salle : allumés à la première visite d'un allié.
static func _light_rooms(sim: Simulation) -> void:
	var st := sim.state()
	if st == null or st.temple_layout.is_empty():
		return
	for room: Dictionary in st.temple_layout["rooms"]:
		if not room["portal"] or GameState.room_portals.has(room["id"]):
			continue
		# Arènes des mini-boss : leur portail de retour s'ouvre à la chute du mini-boss, pas à la visite.
		if room["role"] == "mb1" or room["role"] == "mb2":
			var down := GameState.martyre_state == "defeated" if room["role"] == "mb2" \
				else String(GameState.archipretre.get("mode", "")) == "dead"
			if down:
				GameState.room_portals[room["id"]] = true
				sim.say("Portail de retour ouvert : %s." % room_name(room), 3.0)
			continue
		for u: Unit in GameState.units:
			if u.alive() and not u.hidden and st.temple_room(u.x, u.z).get("id", -1) == room["id"]:
				GameState.room_portals[room["id"]] = true
				var at := room_threshold(st, room)
				Sfx.at("portail", at.x, at.y)
				sim.say("Portail allumé : %s." % room_name(room), 3.0)
				break


# ---------------------------------------------------------------- Rappel d'assaut

## Au-delà de cette distance de l'Ancre, l'Exilé est « en expédition » : l'assaut lui propose de rentrer.
const RECALL_FAR := 80.0
static var _told_wave := 0


## Un assaut est en cours : ennemis de la vague en file ou debout (même test que la fin de vague, Combat).
static func assault_on() -> bool:
	if GameState.wave <= 0:
		return false
	return not GameState.spawn_queue.is_empty() or GameState.enemies.any(func(e: Enemy) -> bool: return e.alive() and not e.beast)


## Le rappel gratuit de cet assaut est-il possible pour l'Exilé `u` (incarné, loin, assaut en cours, pas encore
## servi) ?
static func assault_recall_ready(u: Unit) -> bool:
	return u != null and u == GameState.incarnated and u.alive() and not u.hidden and not warping(u) \
		and GameState.assault_recall_wave != GameState.wave and assault_on() \
		and u.pos().distance_to(CaveShape.CORE) > RECALL_FAR


## Rappel d'assaut (choix du 2026-11-22) : une fois par assaut, sans le mod Ancre de rappel, l'Exilé rentre à la
## capsule, hors combat. Vrai s'il est parti.
static func assault_recall(sim: Simulation, u: Unit) -> bool:
	if not assault_recall_ready(u):
		return false
	if Simulation.in_combat(u):
		sim.say("Rappel d’assaut · impossible en combat.", 2.5)
		return false
	GameState.assault_recall_wave = GameState.wave
	Mods.warp_home(sim, u)
	sim.say("L’Exilé rentre défendre l’Ancre.", 2.5)
	return true


## Annonce, une fois par assaut, quand l'Exilé est loin de l'Ancre.
static func _announce_assault(sim: Simulation) -> void:
	if _told_wave == GameState.wave or GameState.incarnated == null:
		return
	if not assault_recall_ready(GameState.incarnated):
		return
	_told_wave = GameState.wave
	sim.say("Assaut sur l’Ancre ! G : rentrer à la capsule (une fois par assaut).", 5.0)


static func _reflux(sim: Simulation) -> void:
	var st := sim.state()
	var now := GameState.sim_time
	var chan: Array[Dictionary] = []
	var running := false
	for p: Dictionary in st.portals:
		if p.has("reflux"):
			var r: Dictionary = p["reflux"]
			if not linked(p):
				# Canalisation cassée : le pylône redevient sauvage, sa garde reprend (Pylons).
				p.erase("reflux")
				GameState.reflux_next = now + _gap(sim, 1)
				continue
			if r["stage"] == "warn" and now - float(r["at"]) >= WARN:
				r["stage"] = "out"
				r["out_at"] = now
				_release(sim, p)
			elif r["stage"] == "out" and now - float(r["out_at"]) >= OUT:
				p.erase("reflux")
				if p.get("sealed", false) and pack_alive(p) > 0:
					# Canalisation de l'Ingénieur (Pylons.BLESS_CHANNEL) : elle cède si la meute a survécu au reflux.
					p["sealed"] = false
					sim.say("La meute a survécu au reflux : la canalisation de l'Ingénieur cède au %s." % pylon_name(st, p), 4.0)
				else:
					sim.say("Le reflux passe : le %s revient à la normale et son portail rouvre." % pylon_name(st, p), 3.5)
			running = running or p.has("reflux")
		if linked(p) and not p.has("reflux"):
			chan.append(p)
	if running:
		return
	if chan.is_empty():
		GameState.reflux_next = 0.0
		return
	if GameState.reflux_next <= 0.0:
		GameState.reflux_next = now + _gap(sim, chan.size())
		return
	if now < GameState.reflux_next:
		return
	# Jamais pendant la vague de jour.
	if GameState.squads_out > 0 or not GameState.spawn_queue.is_empty():
		GameState.reflux_next = now + WAVE_DELAY
		return
	var rng := Rng.new(st.seed + floori(now * 7.0))
	var p: Dictionary = chan[mini(chan.size() - 1, floori(rng.next() * chan.size()))]
	p["reflux"] = {"stage": "warn", "at": now}
	GameState.reflux_next = now + WARN + OUT + _gap(sim, chan.size())
	var text := "Merenor reprend le %s. Reflux dans 1:00 : défendez ses esprits !" % pylon_name(st, p)
	if p.get("sealed", false):
		text = "Merenor reprend le %s. Reflux dans 1:00 : tuez sa meute avant qu'il passe, ou la canalisation de l'Ingénieur cède !" % pylon_name(st, p)
	sim.say(text, 5.0)
	Events.map_alert.emit(text, float(p["x"]), float(p["z"]))
	Sfx.at("aberration", float(p["x"]), float(p["z"]))


## Intervalle avant le prochain reflux, n pylônes canalisés (environ GAP chacun).
static func _gap(sim: Simulation, n: int) -> float:
	var rng := Rng.new(sim.state().seed + floori(GameState.sim_time * 13.0) + 7)
	return GAP / maxf(1.0, float(n)) * (1.0 + GAP_JITTER * (rng.next() * 2.0 - 1.0))


static func pack_size(tier: int) -> int:
	return mini(int(PACK["cap"]), int(PACK["base"]) + int(PACK["per_tier"]) * tier)


## Sortie : la meute surgit du seuil en couronne et part vers les esprits.
static func _release(sim: Simulation, p: Dictionary) -> void:
	var st := sim.state()
	var at := threshold(st, p)
	var tier := Catalog.menace_tier(GameState.menace) + Biomes.threat_tiers(int(p.get("threat", 1)))
	var stats := Catalog.menace_stats(tier, true)
	var n := pack_size(Catalog.menace_tier(GameState.menace))
	for k in n:
		var q := at + Vector2.from_angle(float(k) / n * TAU) * 1.8
		if not st.walkable(q.x, q.y):
			q = at
		var e := Enemy.make("beast", q.x, q.y, 0.6 + 0.1 * k, stats)
		e.pylon = p
		e.home = q
		e.memo["rank"] = k + 1
		e.memo["reflux"] = true
		e.risen_at = GameState.sim_time + 0.15 * k
		GameState.enemies.append(e)
	Sfx.at("aberration", at.x, at.y)
	var text := "La meute de Merenor sort du %s !" % pylon_name(st, p)
	Events.wave_alert.emit(text, 4.0)
	Events.map_alert.emit(text, float(p["x"]), float(p["z"]))


## Chiens du reflux encore vivants sortis de ce pylône.
static func pack_alive(p: Dictionary) -> int:
	var n := 0
	for e: Enemy in GameState.enemies:
		if e.pylon == p and e.hp > 0.0 and e.memo.get("reflux", false):
			n += 1
	return n


## Cible d'un chien du reflux : l'esprit le plus proche qui prie au pylône, ou null.
static func spirit_target(p: Dictionary, e: Enemy) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in GameState.units:
		if not u.alive() or u.hidden or u.job == null or u.job.get("type") != "pray_pylon" or u.job.get("pylon") != p:
			continue
		var d := Combat.hyp(u.x - e.x, u.z - e.z)
		if d < bd:
			bd = d
			best = u
	return best
