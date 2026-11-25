class_name UnitFeel
extends RefCounted
## Fluidité commune à UnitView et AdeptView (planches/unites-maj-propositions.html, pistes F1 à F3) :
## phase de marche qui part d'un appui et finit son pas à l'arrêt, demi-tour net (un pixel d'affaissement), et, pour les vues
## dessinées à la main (AdeptView), éclair et recul des coups encaissés.

## Demi-tour : durée (s) de l'affaissement d'un pixel. Le sprite passe d'un côté à l'autre d'un coup : plus de largeurs
## intermédiaires (effet « feuille de papier » refusé le 2026-11-23). L'Ingénieur pivote par ses poses de trois quarts
## (UnitView._head_step).
const TURN := 0.09
## Arrêt : tolérance sans déplacement avant de conclure à l'arrêt (s), puis durée maximale pour finir le pas.
const STOP_GRACE := 0.05
const SETTLE_MAX := 0.14
## Coup encaissé : éclair (s), intervalle minimal, recul (s, px), seuil de recul (part des PV).
const HURT_FLASH := 0.12
const HURT_GAP := 0.16
const HURT_RECOIL_T := 0.16
const HURT_RECOIL := 2.0
const HURT_RECOIL_MIN := 0.03

## Phase de marche (0 à 1 par foulée ; appuis en 0 et 0,5) et état.
var wp := 0.0
var walking := false
var _rate := 0.0
var _idle_for := 0.0
var _settle := 0.0
var _face := 0
var _turn_t := -INF
var _last_hp := NAN
var _hurt_t := -INF
var _hurt_k := 0.0
var _recoil_k := 0.0
var _recoil_dir := -1


## Avance la phase de `dist` unités de monde parcourues en `dt` s. Le départ se fait sur un appui ; à l'arrêt
## le pas en cours va jusqu'à l'appui suivant au lieu de se figer en l'air.
func step(dist: float, stride: float, dt: float) -> void:
	if dist > 0.001:
		if not walking:
			walking = true
			wp = 0.0
		wp = fmod(wp + dist / stride, 1.0)
		if dt > 0.0:
			_rate = dist / stride / dt
		_idle_for = 0.0
		_settle = SETTLE_MAX
		return
	if not walking:
		return
	_idle_for += dt
	if dt > 0.0 and _idle_for < STOP_GRACE:
		return
	var goal := 0.5 if wp < 0.5 else 1.0
	var left := goal - wp
	_settle -= dt
	var adv := maxf(_rate, left / maxf(_settle, 0.001)) * dt
	if dt <= 0.0 or adv >= left or _settle <= 0.0:
		wp = fmod(goal, 1.0)
		walking = false
	else:
		wp += adv


## Largeur signée à donner au sprite pour le regard `face` (±1) ; relève l'instant du changement de côté (turning).
func turn(face: int, now: float) -> float:
	if _face == 0:
		_face = face
	if face != _face:
		_face = face
		_turn_t = now
	return float(face)


func turning(now: float) -> bool:
	return now - _turn_t >= 0.0 and now - _turn_t < TURN


## Relève une baisse de PV (toutes sources) : intensité selon la part perdue, recul sur les gros coups.
func track_hurt(hp: float, max_hp: float, face: int, t: float) -> void:
	if is_nan(_last_hp):
		_last_hp = hp
	var drop := _last_hp - hp
	_last_hp = hp
	if drop <= 0.0:
		return
	var share := drop / maxf(1.0, max_hp)
	var k := clampf(0.45 + share * 6.0, 0.45, 1.0)
	if t - _hurt_t < HURT_GAP and k <= flash(t):
		return
	_hurt_t = t
	_hurt_k = k
	_recoil_k = clampf(share * 10.0, 0.5, 1.0) if share >= HURT_RECOIL_MIN else 0.0
	_recoil_dir = -(face if face != 0 else 1)


## Intensité de l'éclair (0 à 1) à l'instant t.
func flash(t: float) -> float:
	var a := t - _hurt_t
	return _hurt_k * (1.0 - a / HURT_FLASH) if a >= 0.0 and a < HURT_FLASH else 0.0


## Recul en pixels natifs entiers (choc immédiat puis retour amorti).
func recoil(t: float) -> float:
	var a := (t - _hurt_t) / HURT_RECOIL_T
	if a < 0.0 or a >= 1.0 or _recoil_k <= 0.0:
		return 0.0
	return _recoil_dir * roundf(HURT_RECOIL * _recoil_k * pow(1.0 - a, 2.0))
