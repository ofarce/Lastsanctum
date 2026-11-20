class_name Unit
extends RefCounted
## Unité alliée (soldier(), Index.html, 73b410f). Les champs reprennent ceux du prototype ; les tâches
## (job : creuser, prier ; build_job ; orb_job) sont des dictionnaires partagés avec les systèmes.

const HP := {"paladin": 180, "healer": 115, "shooter": 110, "engineer": 140}
const DEFAULT_HP := 82

var id := 0
var name := ""
var role := ""
var squad := 0
## Escouades de caserne : effectif initial et ralliement depuis le Puits.
var squad_capacity := 0
## Unité de caserne unique : ×4 dégâts, ×4 armure (et ×4 PV à la sortie).
var power := 1.0
var rejoining := false
var x := 0.0
var z := 0.0
var tx := 0.0
var tz := 0.0
var hp := 0.0
var max_hp := 0.0
var attack := 0.0
var ability := 0.0
var shield := 0.0
var buff := 0.0
## "attack" ou "hold".
var stance := "attack"
var radius := 0.55
var level := 1
var xp := 0.0
var hidden := false
var dead := false
## Ordre de déplacement explicite : l'unité ignore les ennemis jusqu'à destination.
var force_move := false
var job: Variant = null
var build_job: Variant = null
var orb_job := false
var working := false
## Sortie du portail pour une unité qui en émerge (exit), et message d'arrivée.
var exit_point: Variant = null
var arrival := ""
## Esprit en cours d'arrivée à l'autel (Simulation.summon_adept) : fin de l'arrivée (0 sinon) et temple d'origine.
var arrival_end := 0.0
var arrival_temple: Variant = null
## Chemin en cache pour steer (u._path, u._pg, u._pv du prototype).
var memo := {}
## Combat : charge de l'archer (dash {e, t0}, charged), charges du moulinet (orage), prochain sillon (sillonAt).
var dash: Variant = null
var charged := false
var orage := 0
var sillon_at := 0.0
## Prochain jet visuel du lance-flammes (tir continu, D15).
var flame_fx := 0.0
## Orientation imposée par une attaque (u._face) et départ des animations d'attaque (u._swT0, u._sw, u._shT0).
var face := 0
## Surcharge de l'Ancre (sim/overload.gd) : armure perdue ; à genoux, à bout de souffle, à partir de
## winded_at et jusqu'au prochain ordre (INF sinon).
## Paquetage personnel : piles {item, quantity}, 9 999 objets par case ; accessible sans armure.
var inventory: Array[Dictionary] = []
var inventory_capacity := 10
## Équipement porté sans armure : emplacement de la fiche (« Tête », « Torse »…) → objet (data/gear_items.gd).
var equipment: Dictionary = {}
## Ancien porteur des pièces équipées prises à un ennemi : emplacement → nom (absent pour une pièce fabriquée).
var equipment_owner: Dictionary = {}
## Lot transporté par un adepte d'un bâtiment (sim/production.gd) : {item, quantity}, vide sinon.
var carrying: Dictionary = {}
var unarmored := false
## Voile de la Martyre (module d'exo) : instant où il sera reformé ; dernier coup absorbé (éclair).
var veil_ready_at := -INF
var veil_hit_at := -INF
## Dernière ration mangée par l'Exilé (sim/loot.gd).
var ate_at := -INF
var winded_at := INF
## Direction du dernier tir ou coup d'arme (unités de monde, normée) : choisit le tir de face ou de dos.
var aim_dir := Vector2.RIGHT
## Étourdi jusqu'à cet instant (fissure de la Martyre de Byrsa) : ni déplacement ni attaque.
var stunned_until := -INF
## Dernier soin reçu (Puits des Âmes, Soigneur) : petits « + » verts tant qu'il dure (HealFx).
var healed_at := -INF
## Rappel par le Puits des Âmes : instant et position du puits (bulle qui devient l'unité, ReviveFx).
var revived_at := -INF
var revived_from := Vector2.ZERO
var sw_t0 := -INF
var sw := -1
var sh_t0 := -INF


## Ennemi ? (les ennemis dérivent de Unit pour partager le rendu et le déplacement.)
func is_enemy() -> bool:
	return false


static func create(uid: int, unit_name: String, px: float, pz: float, unit_role: String, unit_squad := 0) -> Unit:
	var u := Unit.new()
	u.id = uid
	u.name = unit_name
	u.x = px
	u.z = pz
	u.tx = px
	u.tz = pz
	u.role = unit_role
	u.squad = unit_squad
	u.hp = HP.get(unit_role, DEFAULT_HP)
	u.max_hp = u.hp
	u.radius = 0.85 if unit_role == "paladin" else 0.55
	return u


func pos() -> Vector2:
	return Vector2(x, z)


func alive() -> bool:
	return hp > 0.0
