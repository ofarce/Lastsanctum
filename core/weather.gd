class_name Weather
## Météo de la jungle, tirée à chaque assaut (fonction de la graine et du numéro de vague) :
## clair, couvert, pluie, orage (à partir de la 3e vague). Elle s'installe en quelques secondes.
## Effets : ciel plus sombre, pluie à l'écran, rivière qui monte (River.flood, sans effet sur la
## praticabilité), et sous la pluie tout le monde avance moins vite au dehors.

const KINDS := ["clair", "couvert", "pluie", "orage"]
## Poids des tirages, dans l'ordre de KINDS.
const WEIGHTS := [0.5, 0.25, 0.18, 0.07]
## Mise en place (s).
const RAMP := 8.0
const SPEED := {"clair": 1.0, "couvert": 1.0, "pluie": 0.9, "orage": 0.85}
const FLOOD := {"clair": 0.0, "couvert": 0.0, "pluie": 0.8, "orage": 1.6}
## Obscurité ajoutée au ciel (alpha) et teinte grise.
const GLOOM := {"clair": 0.0, "couvert": 0.12, "pluie": 0.22, "orage": 0.32}
const RAIN := {"clair": 0.0, "couvert": 0.0, "pluie": 0.6, "orage": 1.0}
const GREY := Color(28.0 / 255.0, 34.0 / 255.0, 44.0 / 255.0)
const MESSAGES := {
	"couvert": "Le ciel se couvre au-dessus de la jungle.",
	"pluie": "La pluie tombe sur la jungle : tout le monde y avance moins vite, la rivière monte.",
	"orage": "Un orage éclate : la jungle ralentit tout le monde et la rivière déborde.",
	"clair": "Le ciel se dégage.",
}


static func roll(map_seed: int, wave: int) -> String:
	if wave <= 1:
		return "clair"
	var h := Rng.hash3(wave, 0, map_seed ^ 0x3e7)
	var acc := 0.0
	for k in KINDS.size():
		acc += WEIGHTS[k]
		if h < acc:
			if KINDS[k] == "orage" and wave < 3:
				return "pluie"
			return KINDS[k]
	return "clair"


## Nouvelle vague : nouveau temps. Renvoie le message à afficher, ou "".
static func on_wave(map_seed: int, wave: int) -> String:
	var k := roll(map_seed, wave)
	var prev: String = GameState.weather.get("kind", "clair")
	if k == prev:
		return ""
	GameState.weather = {"kind": k, "from": prev, "since": GameState.sim_time}
	return MESSAGES[k]


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


## Facteur de vitesse au point (x, z) : la pluie ne ralentit que dehors.
static func speed_at(x: float, z: float) -> float:
	if GameState.weather.is_empty() or z < CaveShape.mountain_edge(x):
		return 1.0
	return _value(SPEED)


## Éclair d'orage : intensité 0 → 1 (brefs flashs, pseudo-aléatoires).
static func lightning(t: float) -> float:
	if kind() != "orage" or _blend() < 1.0:
		return 0.0
	var slot := floori(t / 7.0)
	var at := slot * 7.0 + Rng.hash3(slot, 1, 0x11) * 6.0
	var d := t - at
	if d < 0.0 or d > 0.35:
		return 0.0
	return 1.0 - d / 0.35 if d > 0.12 or d < 0.06 else 0.4
