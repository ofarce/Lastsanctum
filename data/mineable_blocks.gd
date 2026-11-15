extends RefCounted
## Ajouter un type ici puis l'affecter aux cellules dans TerrainState.block_types.
## Résistance en coups ; chaque bloc produit exactement un exemplaire de drop_item.
const TYPES := {
	"rock": {"resistance": 4, "material_name": "Roche", "mining_label": "Creuse la roche", "drop_item": "rock"},
}
const ITEMS := {
	"rock": {"name": "Roche", "color": Color("#89969c")},
}
