class_name Capsule
extends RefCounted
## Capsule de l'Ingénieur, à la place du portail central des Exilés (Simulation.PORTAL). À moins d'un
## bloc, « E : Entrer » s'affiche dessus ; E y fait entrer l'Ingénieur (il disparaît, le jeu passe en mode
## désincarné et il ne peut plus bouger ; il y est soigné), un nouvel appui sur E l'en fait sortir et le réincarne.
## Depuis le 2026-11-22 (planches/intro-capsule-planche.html), la partie commence dans la capsule éteinte : on n'en sort
## qu'une fois l'Ancre rallumée (powered). L'équipement de départ vient du Coffre Antique voisin (Simulation.open_chest).

## Pied de la capsule, posé devant la paroi nord.
const POS := Vector2(0.0, -165.5)
const RANGE := 4.0  # un bloc (case de 4 unités)
const EXIT := Vector2(0.0, -162.5)
## Vue fixe de la caméra tant que l'Ingénieur est dans la capsule (WorldCamera.capsule_lock) : capsule, Coffre et Ancre.
const VIEW := Vector2(2.0, -160.0)


## Dans la capsule, l'Ingénieur régénère HEAL_RATE PV par seconde (jusqu'à ses PV maximum) et chaque mana
## gagne MANA_RATE par seconde (2026-11-19).
const HEAL_RATE := 5.0
const MANA_RATE := 2.0


static func tick(dt: float) -> void:
	if not GameState.in_capsule or not powered():
		return
	var u := engineer()
	if u == null:
		return
	u.hp = minf(u.max_hp, u.hp + HEAL_RATE * dt)
	if not GameState.ended:
		for resource: String in Catalog.RES_ORDER:
			GameState.res[resource] += MANA_RATE * dt


static func engineer() -> Unit:
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive():
			return u
	return null


## Réveil de l'Ancre au clavier : Ingénieur incarné à un bloc du socle (rayon du socle ~3 + 4).
const ANCHOR_REACH := 7.0


## Emprises au sol infranchissables, calées sur les dessins (puits de l'Ancre, bornes comprises ≈ x ±3,7, z −155,9…−152,4 ;
## puits de lumière de la capsule, margelle et bornes comprises ≈ x ±2,1, z −167…−165,1) et élargies de
## MARGIN, le corps des unités autour de leur point de contact.
const MARGIN := 0.6


static func solid_rects() -> Array[Rect2]:
	var capsule := Rect2(POS.x - 2.1, POS.y - 1.5, 4.2, 1.9)
	return [anchor_solid(), capsule.grow(MARGIN), chest_solid()]


## Socle du Coffre Antique (dessin de 42 px natifs de large, face avant au sol en CaveShape.CHEST), élargi de MARGIN.
static func chest_solid() -> Rect2:
	return Rect2(CaveShape.CHEST.x - 2.5, CaveShape.CHEST.y - 2.2, 5.25, 2.4).grow(MARGIN)


## Le Coffre Antique est éteint tant que l'Ancre l'est : il ne s'ouvre pas.
static func chest_active() -> bool:
	return GameState.orb_active


## L'Ingénieur incarné est à un bloc du Coffre Antique allumé et encore fermé (« E : Ouvrir le Coffre Antique »).
static func can_open_chest() -> bool:
	var eng := GameState.incarnated
	return eng != null and eng.role == "engineer" and chest_active() and not GameState.base_inventory_unlocked \
		and eng.pos().distance_to(CaveShape.CHEST_SPOT) <= RANGE


## Socle infranchissable de l'Ancre (élargi de MARGIN).
static func anchor_solid() -> Rect2:
	return Rect2(CaveShape.CORE.x - 3.7, CaveShape.CORE.y - 1.9, 7.4, 3.5).grow(MARGIN)


## Point du bord du socle de l'Ancre le plus proche de `p` : c'est lui qu'un assaillant atteint, le centre du
## puits est hors d'allonge depuis que le socle ne se traverse plus.
static func anchor_edge(p: Vector2) -> Vector2:
	var r := anchor_solid()
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


static func set_solid(st: TerrainState) -> void:
	if st == null:
		return
	st.solids = solid_rects()
	st.version += 1


## Prière à l'Ancre éveillée (E), Ingénieur incarné à un bloc.
static func can_pray_anchor() -> bool:
	var eng := GameState.incarnated
	return eng != null and eng.role == "engineer" and GameState.orb_active \
		and eng.pos().distance_to(CaveShape.CORE) <= ANCHOR_REACH


static func praying(u: Unit) -> bool:
	return u != null and u.job != null and u.job.get("type") == "anchor_pray"


static func can_wake_anchor() -> bool:
	var eng := GameState.incarnated
	return eng != null and eng.role == "engineer" and not GameState.orb_active and not eng.orb_job \
		and eng.pos().distance_to(CaveShape.CORE) <= ANCHOR_REACH


## Capsule allumée : alimentée par l'Ancre (trait arrivé) ; sans séquence d'ouverture, dès le réveil.
static func powered() -> bool:
	return GameState.capsule_on or (GameState.opening_stage == "" and GameState.orb_active)


## L'Ingénieur, dehors, est assez près pour entrer (capsule allumée seulement).
static func can_enter() -> bool:
	var eng := engineer()
	return eng != null and powered() and not GameState.in_capsule and not eng.hidden \
		and eng.pos().distance_to(POS) <= RANGE


## Appui sur E : entrer ou sortir de la capsule, ouvrir le Coffre Antique, ou réveiller l'Ancre (partie sans
## ouverture). Vrai si l'appui a servi.
static func toggle(sim: Simulation) -> bool:
	if sim and can_open_chest():
		sim.open_chest_incarnated(GameState.incarnated)
		return true
	if sim and can_wake_anchor():
		sim.order_orb(GameState.incarnated)
		return true
	if sim and can_pray_anchor():
		var u := GameState.incarnated
		if praying(u):
			sim.cancel_work(u)
		else:
			sim.set_job(u, {"type": "anchor_pray"})
		return true
	var eng := engineer()
	if eng == null:
		return false
	if GameState.in_capsule:
		if not powered() or Opening.cinematic():
			return false
		GameState.in_capsule = false
		eng.hidden = false
		eng.x = EXIT.x
		eng.z = EXIT.y
		eng.tx = eng.x
		eng.tz = eng.z
		ExileGallery.incarnate(eng)
		return true
	if not can_enter():
		return false
	if sim:
		sim.cancel_work(eng)
	GameState.in_capsule = true
	ExileGallery.disincarnate()
	eng.hidden = true
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.selected.erase(eng)
	return true
