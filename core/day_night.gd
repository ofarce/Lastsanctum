class_name DayNight
## Cycle jour/nuit de la jungle, fonction pure du temps de simulation. La partie commence en début de
## matinée. Seul le dehors (au sud du flanc de la montagne) change : la caverne et les galeries gardent
## leur ambiance. Les sources de lumière (torches, bâtiments, Ancre…) creusent l'obscurité la nuit.

## Durée d'une journée complète (s de simulation) et position de départ dans la journée (0 = aube).
const LENGTH := 240.0
const START := 0.1
## Bornes des phases, en fraction de journée : aube, jour, crépuscule, nuit.
const DAWN_END := 0.08
const DUSK_START := 0.6
const DUSK_END := 0.68

## Obscurité du dehors (couleur non prémultipliée, alpha = opacité) : jour (celle du prototype),
## crépuscule, nuit.
const DAY := Color(12.0 / 255.0, 7.0 / 255.0, 4.0 / 255.0, 0.28)
const DUSK := Color(96.0 / 255.0, 34.0 / 255.0, 30.0 / 255.0, 0.5)
## Nuit au clair de lune (2026-11-20) : bleue et assez claire pour lire les silhouettes hors des halos.
const NIGHT := Color(12.0 / 255.0, 20.0 / 255.0, 54.0 / 255.0, 0.66)


## Assauts : un chaque matin, à FIRST_WAVE_HOUR (voir next_assault). MORNING : début de matinée,
## pour les reports d'un assaut tombé de nuit.
const MORNING := 0.12
## Répit minimal entre la fin d'un assaut et le suivant (s) : un assaut fini juste avant 9 h
## reporte le suivant au lendemain.
const WAVE_REST := 30.0


## Numéro du jour (1 = premier jour de la partie) à l'instant t.
static func day(t: float) -> int:
	return floori(t / LENGTH + START) + 1


## Premier assaut de la partie : jour FIRST_WAVE_DAY à FIRST_WAVE_HOUR (2026-11-19).
const FIRST_WAVE_DAY := 2
const FIRST_WAVE_HOUR := 9.0


## Instant où l'horloge affiche `hour` (heures, 24 h) le jour n.
static func at_hour(n: int, hour: float) -> float:
	var f := fposmod(hour - DAWN_HOUR, 24.0) / 24.0
	# Une fraction de seconde en plus : l'horloge (arrondie à la minute inférieure) affiche bien l'heure pile.
	return (float(n - 1) + f - START) * LENGTH + 0.01


## Premier assaut : 9 h du jour 2, ou 9 h du lendemain si cette heure est déjà passée à l'instant t.
static func first_wave(t: float) -> float:
	var at := at_hour(FIRST_WAVE_DAY, FIRST_WAVE_HOUR)
	while at <= t:
		at += LENGTH
	return at


## Instant du matin (MORNING) du jour n.
static func morning(n: int) -> float:
	return (float(n - 1) + MORNING - START) * LENGTH


static func is_day(t: float) -> bool:
	return phase(t) == "jour"


## Heure du début de l'aube (fraction 0), pour l'horloge de l'interface.
const DAWN_HOUR := 5.5


## Heure affichée « HH:MM » (24 h).
static func clock(t: float) -> String:
	var m := floori(fposmod(DAWN_HOUR + fraction(t) * 24.0, 24.0) * 60.0)
	return "%02d:%02d" % [m / 60, m % 60]


## Moment de la journée, pour l'interface.
static func label(t: float) -> String:
	var f := fraction(t)
	if f < DAWN_END:
		return "aube"
	if f < 0.25:
		return "matin"
	if f < 0.42:
		return "midi"
	if f < DUSK_START:
		return "après-midi"
	if f < DUSK_END:
		return "crépuscule"
	return "nuit"


## Prochain assaut après une zone sécurisée à l'instant t : le matin suivant, à FIRST_WAVE_HOUR
## (un assaut par jour), en laissant au moins WAVE_REST de répit.
static func next_assault(t: float, _wave: int = 0, _map_seed: int = 0) -> float:
	var at := at_hour(day(t), FIRST_WAVE_HOUR)
	while at < t + WAVE_REST:
		at += LENGTH
	return at


## Premier instant de jour à partir de t (t lui-même s'il fait jour).
static func next_daylight(t: float) -> float:
	if is_day(t):
		return t
	var n := day(t)
	return morning(n) if morning(n) > t else morning(n + 1)


## Fraction de la journée (0 → 1) à l'instant t.
static func fraction(t: float) -> float:
	return fposmod(t / LENGTH + START, 1.0)


static func phase(t: float) -> String:
	var f := fraction(t)
	if f < DAWN_END:
		return "aube"
	if f < DUSK_START:
		return "jour"
	if f < DUSK_END:
		return "crépuscule"
	return "nuit"


## 0 en plein jour, 1 en pleine nuit, rampes à l'aube et au crépuscule.
static func night(t: float) -> float:
	var f := fraction(t)
	if f < DAWN_END:
		return 1.0 - smoothstep(0.0, DAWN_END, f)
	if f < DUSK_START:
		return 0.0
	if f < DUSK_END:
		return smoothstep(DUSK_START, DUSK_END, f)
	return 1.0


## Obscurité du dehors à l'instant t : teinte rosée au milieu des transitions.
static func sky(t: float) -> Color:
	var n := night(t)
	var glow := 1.0 - absf(n - 0.5) * 2.0
	var base := DAY.lerp(NIGHT, n)
	return base.lerp(DUSK, glow * 0.7)
