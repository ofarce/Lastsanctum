class_name EngineerReturn
## Mort et retour de l'Ingénieur (planches/ingenieur-mort-planche.html, choix du 2026-11-23 : M2 Foudroyé →
## R2 Le feu follet → A2 Les quatre bornes → S3 Le souffle). Aucune règle ici : seulement le calendrier que suivent
## les vues (world/capsule/engineer_fall_view.gd, capsule_view.gd) et la caméra. Tout se joue à l'intérieur du
## délai Simulation.ENGINEER_RESPAWN, compté depuis la chute ; le souffle tombe sur l'instant du retour.

## Chute : arrêt sur image, vol, rebond, lumières qui meurent.
const FALL := 1.5
## Corps au sol avant de se défaire.
const HOLD := 0.3
## Le corps se défait en grains, de la tête aux pieds, et le feu follet se forme.
const DISSOLVE := 0.75
## Vol du feu follet jusqu'à la colonne (durée fixe, quelle que soit la distance), plongée comprise.
const FLIGHT := 1.0
const DIVE := 0.25
const ARRIVE := FALL + HOLD + DISSOLVE + FLIGHT
## Résurrection : la colonne se resserre (RES_PRE avant le retour, dont RES_DARK de noir), puis le souffle.
const RES_PRE := 0.6
const RES_DARK := 0.15
const RES_POST := 1.0


## Secondes écoulées depuis la chute ; INF hors de la séquence.
static func age() -> float:
	if GameState.engineer_respawn_at == INF:
		return INF
	return GameState.sim_time - (GameState.engineer_respawn_at - Simulation.ENGINEER_RESPAWN)


## Feu follet arrivé dans le puits : la capsule compte (les quatre bornes).
static func waiting() -> bool:
	return age() != INF and age() >= ARRIVE


## Avancée de l'attente, de l'arrivée du feu follet au début du resserrement (0 à 1) ; −1 hors attente.
static func wait_k() -> float:
	var a := age()
	if a == INF or a < ARRIVE:
		return -1.0
	return clampf((a - ARRIVE) / (Simulation.ENGINEER_RESPAWN - RES_PRE - ARRIVE), 0.0, 1.0)


## Temps par rapport au souffle (négatif = resserrement, positif = après le retour) ; INF hors de la résurrection.
static func res_t() -> float:
	if GameState.engineer_respawn_at != INF:
		var left := GameState.engineer_respawn_at - GameState.sim_time
		return -left if left <= RES_PRE else INF
	var since := GameState.sim_time - GameState.engineer_back_at
	return since if since >= 0.0 and since < RES_POST else INF


## Avancée du vol du feu follet (0 à 1) ; −1 hors vol.
static func flight_k() -> float:
	var a := age()
	if a == INF or a < ARRIVE - FLIGHT or a >= ARRIVE:
		return -1.0
	return (a - (ARRIVE - FLIGHT)) / FLIGHT


## La caméra accompagne le feu follet (l'Ingénieur était incarné à sa mort) : avancée 0 à 1, −1 sinon.
static func camera_k() -> float:
	return flight_k() if GameState.engineer_fell_follow else -1.0
