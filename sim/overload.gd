class_name Overload
extends RefCounted
## Surcharge de l'Ancre (planche ancre-surcharge-propositions.html, proposition 5 « Rupture du sceau ») :
## quand la caméra est revenue sur l'Ingénieur après l'armement des balistes, les segments de l'anneau
## runique éclatent un à un et la sphère se soulève, une colonne d'ombre monte vers le ciel, puis une double
## nova part de l'Ancre. L'Ingénieur lève son bouclier d'Énonciation, qui se fend puis vole en éclats :
## l'armure est soufflée, il retombe à genoux à 1 PV, sans équipement. Le dialogue vient ensuite.
##
## La partie « jeu » vit ici (temps, gel de l'Ingénieur, PV, perte de l'armure) ; le rendu est dans
## world/anchor/anchor_overload.gd. Tous les instants sont en secondes depuis GameState.overload_at,
## ou depuis l'impact de la nova (GameState.overload_hit) pour ce qui suit.

## Surcharge : les 8 segments de l'anneau cèdent entre OV_START et COLUMN.
const OV_START := 0.6
const COLUMN := 2.4
const NOVA := 3.15
## Vitesse de la nova : demi-grand axe de l'ellipse au sol, en pixels natifs par seconde.
const NOVA_SPEED := 118.0
## Aplatissement de l'ellipse au sol (comme les ombres des unités).
const FLAT := 0.47
## Relatifs à l'impact : bouclier levé, éclatement (PV et armure perdus), chute à genoux, dialogue.
const SHIELD := -0.2
const BLAST := 0.32
const LAND := 0.72
const FALL := 0.2
const DIALOGUE := 2.2
## Fin de la colonne, puis l'anneau se rallume segment par segment.
const COLUMN_FADE := 1.4
const COLUMN_FADE_LEN := 1.6
const RELIGHT := 3.0
const RELIGHT_STEP := 0.1
const END := RELIGHT + 8 * RELIGHT_STEP + 0.2


static func active() -> bool:
	return GameState.overload_at != INF


## Temps écoulé depuis le début de l'événement, ou −1 hors événement.
static func time() -> float:
	return GameState.sim_time - GameState.overload_at if active() else -1.0


## Temps écoulé depuis l'impact de la nova (négatif avant), ou NAN hors événement.
static func since_hit() -> float:
	return GameState.sim_time - GameState.overload_hit if active() else NAN


## Repère de l'orbe (Ancre active, sans l'oscillation), en pixels natifs : centre de la sphère en (0, −8),
## 24 px au-dessus du puits (AnchorView : SUNK + RISE).
static func orb_origin() -> Vector2:
	return Proj.nat(CaveShape.CORE.x, 0.0, CaveShape.CORE.y) + Vector2(0.0, -16.0)


## Centre de la nova au sol (puits de l'Ancre), en pixels natifs.
static func ring_center() -> Vector2:
	return Proj.nat(CaveShape.CORE.x, 0.0, CaveShape.CORE.y)


## Rayon (demi-grand axe) auquel la nova atteint un point du sol donné en pixels natifs.
static func reach(p: Vector2) -> float:
	var d := p - ring_center()
	return maxf(8.0, sqrt(d.x * d.x + (d.y / FLAT) * (d.y / FLAT)))


## Segment k (0..7) de l'anneau rompu à l'instant t (secondes depuis le début), puis rallumé.
static func segment_broken(k: int, t: float) -> bool:
	if t < segment_break_at(k):
		return false
	var h := GameState.sim_time - GameState.overload_hit
	return h < RELIGHT + k * RELIGHT_STEP


## Instant de rupture du segment k (secondes depuis le début).
static func segment_break_at(k: int) -> float:
	return OV_START + (k + 1) / 9.0 * (COLUMN - OV_START)


## Masque des segments rompus (flash = vrai : segments dans leur éclat de 0,12 s, à la rupture ou au rallumage).
static func ring_mask(flash: bool) -> int:
	var t := time()
	if t < 0.0:
		return 0
	var h := since_hit()
	var m := 0
	for k in 8:
		var b := segment_break_at(k)
		var back := RELIGHT + k * RELIGHT_STEP
		if flash:
			if (t >= b and t < b + 0.12) or (h >= back and h < back + 0.12):
				m |= 1 << k
		elif segment_broken(k, t):
			m |= 1 << k
	return m


## Soulèvement de la sphère, en pixels natifs (entiers).
static func sphere_lift() -> int:
	var t := time()
	if t < OV_START:
		return 0
	var up := clampf((t - OV_START) / (COLUMN - OV_START), 0.0, 1.0)
	var h := since_hit()
	if h > COLUMN_FADE:
		up *= 1.0 - clampf((h - COLUMN_FADE) / (RELIGHT - COLUMN_FADE), 0.0, 1.0)
	return roundi(up * 5.0 + sin(GameState.sim_time * 20.0) * up * 0.6)


## Lance l'événement pour l'Ingénieur `u` (une seule fois par partie).
static func start(u: Unit) -> bool:
	if active() or u == null or not u.alive() or u.hidden:
		return false
	GameState.overload_at = GameState.sim_time
	GameState.overload_unit = u
	GameState.overload_stage = 1
	GameState.overload_hit = GameState.sim_time + NOVA + reach(Proj.nat(u.x, 0.0, u.z)) / NOVA_SPEED
	return true


## Avance l'événement. Renvoie vrai à l'instant où le dialogue doit s'ouvrir.
static func tick() -> bool:
	var u := GameState.overload_unit
	if not active() or u == null:
		return false
	if GameState.overload_stage < 3 and (not u.alive() or u.hidden):
		GameState.overload_stage = 3
		return false
	var h := since_hit()
	if GameState.overload_stage < 3:
		# Pris dans la séquence : l'Ingénieur reste sur place, ses tâches sont suspendues.
		u.tx = u.x
		u.tz = u.z
		u.force_move = false
		u.memo.clear()
	if GameState.overload_stage == 1 and h >= BLAST:
		GameState.overload_stage = 2
		u.hp = minf(u.hp, 1.0)
		u.unarmored = true
		if u.job != null and u.job.get("type") == "dig" and not Simulation.can_mine(u):
			u.job = null
			u.working = false
		u.winded_at = GameState.overload_hit + LAND
	if GameState.overload_stage == 2 and h >= DIALOGUE:
		GameState.overload_stage = 3
		return true
	return false


## L'Ingénieur reste à genoux, à bout de souffle, jusqu'à son prochain ordre.
static func winded(u: Unit) -> bool:
	if u.winded_at == INF or GameState.sim_time < u.winded_at:
		return false
	if GameState.overload_stage >= 3 and (u.force_move or u.job != null or u.build_job != null or u.orb_job \
			or Vector2(u.tx - u.x, u.tz - u.z).length() > 0.05):
		u.winded_at = INF
		return false
	return true


## Instants de l'éclatement : l'Ingénieur n'est pas dessiné entre l'éclatement et la chute à genoux.
static func hidden_in_blast(u: Unit) -> bool:
	if GameState.overload_unit != u:
		return false
	var h := since_hit()
	return h >= BLAST + 0.04 and h < LAND
