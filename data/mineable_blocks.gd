extends RefCounted
## Ajouter un type ici puis l'affecter aux cellules dans TerrainState.block_types.
## Résistance en coups ; chaque bloc produit exactement un exemplaire de drop_item.
const TYPES := {
	"gold": {"resistance": 4, "material_name": "Or", "mining_label": "Mine l’or", "drop_item": "gold"},
	"quartz": {"resistance": 4, "material_name": "Quartz", "mining_label": "Mine le quartz", "drop_item": "quartz"},
	"iron": {"resistance": 4, "material_name": "Fer", "mining_label": "Mine le fer", "drop_item": "iron"},
	"copper": {"resistance": 4, "material_name": "Cuivre", "mining_label": "Mine le cuivre", "drop_item": "copper"},
	"rock": {"resistance": 4, "material_name": "Roche", "mining_label": "Creuse la roche", "drop_item": "rock"},
}
const ITEMS := {
	"gold": {"name": "Or", "color": Color("#ddb457")},
	"quartz": {"name": "Quartz", "color": Color("#c5b5d8")},
	"iron": {"name": "Fer", "color": Color("#8796a2")},
	"copper": {"name": "Cuivre", "color": Color("#c47b58")},
	"rock": {"name": "Roche", "color": Color("#89969c")},
}

const ORES := ["copper", "iron", "quartz", "gold"]
