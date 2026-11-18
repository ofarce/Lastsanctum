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
const NIGHT := Color(5.0 / 255.0, 9.0 / 255.0, 32.0 / 255.0, 0.8)


## Assauts : seulement le jour, un tous les WAVE_DAYS jours (tirage 2 ou 3), au MORNING de la journée.
const WAVE_DAYS := [2, 3]
const MORNING := 0.12


## Numéro du jour (1 = premier jour de la partie) à l'instant t.
static func day(t: float) -> int:
	return floori(t / LENGTH + START) + 1


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


## Prochain assaut après une zone sécurisée à l'instant t : matin d'un jour 2 ou 3 jours plus tard.
static func next_assault(t: float, wave: int, map_seed: int) -> float:
	var gap: int = WAVE_DAYS[0] if Rng.hash3(wave, 7, map_seed) < 0.5 else WAVE_DAYS[1]
	return morning(day(t) + gap)


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
