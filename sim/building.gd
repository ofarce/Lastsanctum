class_name Building
extends RefCounted
## Bâtiment du sanctuaire (objet b de placeBuilding, buildings.js, 73b410f) : chantier, puis bâtiment achevé
## (temple, caserne, Puits des Âmes…). La logique est dans Simulation ; le rendu dans BuildingView.

var id := 0
var type := ""
var x := 0.0
var z := 0.0
## Ingénieur du chantier (b.owner), ou null. Référence faible : l'Ingénieur pointe déjà vers son
## chantier (build_job), et un cycle de RefCounted ne serait jamais libéré.
var owner: Unit:
	get:
		return _owner.get_ref() if _owner else null
	set(value):
		_owner = weakref(value) if value else null
var _owner: WeakRef = null
## Temps d'Énonciation écoulé (sur BUILDINGS[type].time).
var progress := 0.0
var complete := false
## File d'entraînement de la caserne (identifiants d'adeptes combattants).
var queue: Array[String] = []
var train := 0.0
## Point où l'Ingénieur se tient pendant l'Énonciation (b.spot, workSpot).
var spot := Vector2.ZERO
## Instant d'achèvement (b.finishedAt), INF tant que le chantier n'est pas fini.
var finished_at := INF
## Cumul de prière pour les popups « +5 » (t._acc).
var acc := 0.0


static func create(bid: int, btype: String, px: float, pz: float) -> Building:
	var b := Building.new()
	b.id = bid
	b.type = btype
	b.x = px
	b.z = pz
	return b


func def() -> Dictionary:
	return Catalog.BUILDINGS[type]


func half() -> float:
	return int(def()["size"]) * 4.0 / 2.0


func is_temple() -> bool:
	return not String(def()["deity"]).is_empty()
