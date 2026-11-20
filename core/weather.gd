class_name Weather
## Météo de la jungle : elle change par tranches de journée (fonction de la graine et de la tranche) :
## clair, couvert, pluie, orage (à partir du 3e jour), brume. Elle s'installe en quelques secondes.
## Effets : ciel plus sombre, pluie à l'écran ; sous la pluie tout le monde avance moins vite au dehors,
## la rivière sort de son lit (River.flood) et la zone inondée ralentit nettement (WADE), les flammes ne
## brûlent plus la végétation (wet), et celle-ci repousse d'un stade quand la pluie commence. Sous l'orage,
## la foudre frappe un combattant au dehors (Combat.lightning_strike) ; dans la brume, les tireurs portent
## moins loin (reach_at).

const KINDS := ["clair", "couvert", "pluie", "orage", "brume"]
## Poids des tirages, dans l'ordre de KINDS.
const WEIGHTS := [0.36, 0.2, 0.22, 0.12, 0.1]
## Mise en place (s).
const RAMP := 8.0
const SPEED := {"clair": 1.0, "couvert": 1.0, "pluie": 0.9, "orage": 0.85, "brume": 1.0}
const FLOOD := {"clair": 0.0, "couvert": 0.0, "pluie": 1.5, "orage": 3.5, "brume": 0.0}
## Tranches de temps par journée, et chance qu'une tranche garde le temps de la précédente.
const SLOTS := 4
const STAY := 0.45
## Vitesse dans la zone inondée (les tabliers des ponts restent au sec).
const WADE := 0.6
const NAMES := {"clair": "Clair", "couvert": "Couvert", "pluie": "Pluie", "orage": "Orage", "brume": "Brume"}

## Rivière de la partie en cours (posée par tick), pour la zone inondée.
static var river: River
## Chemins de la partie en cours (posés par tick) : on y marche plus vite, par tous les temps.
static var road: Road
const ROAD_SPEED := 1.1
## Obscurité ajoutée au ciel (alpha) et teinte grise.
const GLOOM := {"clair": 0.0, "couvert": 0.12, "pluie": 0.22, "orage": 0.32, "brume": 0.08}
const RAIN := {"clair": 0.0, "couvert": 0.0, "pluie": 0.6, "orage": 1.0, "brume": 0.0}
## Brume : voile à l'écran (0 → 1) et portée des tireurs au dehors.
const MIST := {"clair": 0.0, "couvert": 0.0, "pluie": 0.0, "orage": 0.0, "brume": 1.0}
const REACH := {"clair": 1.0, "couvert": 1.0, "pluie": 1.0, "orage": 1.0, "brume": 0.6}
## Foudre (orage) : un impact par période, dégâts bruts, rayon d'abri autour d'un bâtiment ou d'une tourelle.
const BOLT_PERIOD := 7.0
const BOLT_DAMAGE := 40.0
const BOLT_SHELTER := 8.0
## Tirages vides ajoutés aux combattants : un Exilé seul dehors n'est frappé qu'une fois sur 9.
const BOLT_MISSES := 8
const BOLT_COLOR := Color(0.86, 0.92, 1.0)
const GREY := Color(28.0 / 255.0, 34.0 / 255.0, 44.0 / 255.0)
const MESSAGES := {
	"couvert": "Le ciel se couvre au-dessus de la jungle.",
	"pluie": "La pluie tombe sur la jungle : on y avance moins vite, la rivière monte, le feu ne prend plus.",
	"orage": "Un orage éclate : la rivière déborde et la foudre frappe au dehors, loin des bâtiments.",
	"clair": "Le ciel se dégage.",
	"brume": "La brume se lève sur la jungle : dehors, les tireurs portent moins loin.",
}


## Tranche de temps : la journée en compte SLOTS (aube, fin de matinée, fin d'après-midi, nuit).
static func slot(t: float) -> int:
	return floori((t / DayNight.LENGTH + DayNight.START) * SLOTS)


## Instant où commence la tranche s.
static func slot_time(s: int) -> float:
	return (float(s) / SLOTS - DayNight.START) * DayNight.LENGTH


## Temps de la tranche s, fonction pure de la graine. Le premier jour est clair ; une tranche garde
## souvent le temps de la précédente (STAY) ; pas d'orage avant le troisième jour.
static func kind_at(map_seed: int, s: int) -> String:
	if s < SLOTS:
		return "clair"
	var k := s
	for n in 3:
		if k - 1 < SLOTS or Rng.hash3(k, 2, map_seed ^ 0x3e7) >= STAY:
			break
		k -= 1
	var h := Rng.hash3(k, 0, map_seed ^ 0x3e7)
	var acc := 0.0
	for i in KINDS.size():
		acc += WEIGHTS[i]
		if h < acc:
			if KINDS[i] == "orage" and k < 2 * SLOTS:
				return "pluie"
			return KINDS[i]
	return "clair"


## À chaque tick : passe au temps de la tranche courante, tient la crue de la rivière à jour, et fait
## repousser la végétation d'un stade quand la pluie commence. Renvoie le message à afficher, ou "".
## Un temps posé à la main (sans « slot » : tests, captures) n'est pas remplacé.
static func tick(st: TerrainState) -> String:
	river = st.river
	road = st.road
	if river:
		river.flood = flood()
	if not GameState.weather.is_empty() and not GameState.weather.has("slot"):
		return ""
	var s := slot(GameState.sim_time)
	if int(GameState.weather.get("slot", -1)) == s:
		return ""
	var k := kind_at(st.seed, s)
	var prev := kind()
	if k == prev:
		GameState.weather["slot"] = s
		GameState.weather["seed"] = st.seed
		GameState.weather["kind"] = k
		return ""
	GameState.weather = {"kind": k, "from": prev, "since": GameState.sim_time, "slot": s, "seed": st.seed}
	if RAIN[k] > 0.0 and RAIN[prev] == 0.0 and st.flora:
		st.flora.regrow()
	return MESSAGES[k]


## Prochain changement de temps dans la journée qui vient : {kind, at (instant)}, ou {} si rien ne change
## (ou si le temps a été posé à la main).
static func forecast() -> Dictionary:
	if not GameState.weather.has("seed"):
		return {}
	var s0 := slot(GameState.sim_time)
	for s in range(s0 + 1, s0 + 1 + SLOTS):
		var k := kind_at(int(GameState.weather["seed"]), s)
		if k != kind():
			return {"kind": k, "at": slot_time(s)}
	return {}


static func kind() -> String:
	return GameState.weather.get("kind", "clair")


## Mélange 0 → 1 entre le temps précédent et le courant.
static func _blend() -> float:
	return clampf((GameState.sim_time - float(GameState.weather.get("since", -INF))) / RAMP, 0.0, 1.0)


static func _value(table: Dictionary) -> float:
	var from: String = GameState.weather.get("from", "clair")
	return lerpf(float(table[from]), float(table[kind()]), _blend())


static func rain() -> float:
	return _value(RAIN)


static func gloom() -> float:
	return _value(GLOOM)


static func flood() -> float:
	return _value(FLOOD)


## Facteur de vitesse au point (x, z) : terrain et météo. Sur un chemin de la jungle, ×ROAD_SPEED ; la
## pluie ne ralentit que dehors. `wade` faux : la zone inondée ne gêne pas (crocodiles).
static func speed_at(x: float, z: float, wade := true) -> float:
	if z < Road.GATE_Z - 20.0:
		return 1.0
	var v := ROAD_SPEED if road != null and road.on_road(x, z) else 1.0
	if GameState.weather.is_empty() or z < CaveShape.mountain_edge(x):
		return v
	v *= _value(SPEED)
	if wade and river != null and river.flood > 0.0 and absf(z - River.MID_Z) < 20.0 and river.flooded(x, z):
		v *= WADE
	return v


## Végétation trempée au point (x, z) : les flammes ne la brûlent plus.
static func wet(x: float, z: float) -> bool:
	return z >= CaveShape.mountain_edge(x) and rain() > 0.3


## Voile de brume à l'écran, 0 → 1.
static func mist() -> float:
	return _value(MIST)


## Facteur de portée des tireurs au point (x, z) : la brume ne gêne que dehors.
static func reach_at(x: float, z: float) -> float:
	if GameState.weather.is_empty() or z < CaveShape.mountain_edge(x):
		return 1.0
	return _value(REACH)


## Instant de l'éclair de la période n (une par BOLT_PERIOD).
static func bolt_time(n: int) -> float:
	return n * BOLT_PERIOD + Rng.hash3(n, 1, 0x11) * (BOLT_PERIOD - 1.0)


## Période dont l'éclair tombe dans ]t0, t1], ou −1 : l'orage doit être installé.
static func bolt_between(t0: float, t1: float) -> int:
	if kind() != "orage" or _blend() < 1.0:
		return -1
	var n := floori(t1 / BOLT_PERIOD)
	var at := bolt_time(n)
	return n if at > t0 and at <= t1 else -1


## Éclair d'orage : intensité 0 → 1 (brefs flashs, pseudo-aléatoires).
static func lightning(t: float) -> float:
	if kind() != "orage" or _blend() < 1.0:
		return 0.0
	var d := t - bolt_time(floori(t / BOLT_PERIOD))
	if d < 0.0 or d > 0.35:
		return 0.0
	return 1.0 - d / 0.35 if d > 0.12 or d < 0.06 else 0.4
