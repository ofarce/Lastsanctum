extends RefCounted
## Ajouter un type ici puis l'affecter aux cellules dans TerrainState.block_types.
## Résistance en coups ; chaque bloc produit exactement un exemplaire de drop_item.
const TYPES := {
	"gold": {"resistance": 4, "material_name": "Or", "mining_label": "Mine l’or", "drop_item": "gold"},
	"quartz": {"resistance": 4, "material_name": "Quartz", "mining_label": "Mine le quartz", "drop_item": "quartz"},
	"iron": {"resistance": 4, "material_name": "Fer", "mining_label": "Mine le fer", "drop_item": "iron"},
	"copper": {"resistance": 4, "material_name": "Cuivre", "mining_label": "Mine le cuivre", "drop_item": "copper"},
	"rock": {"resistance": 4, "material_name": "Roche", "mining_label": "Creuse la roche", "drop_item": "rock"},
	## Roche du biome 2 (Veines de vert-de-gris) : deux fois plus dure, et impossible à entamer sans la recherche
	## « seal » (Sceau de cuivre, à la Forge). Toute case de roche sans type propre au nord du Temple (TerrainState.block_definition).
	"rock2": {"resistance": 8, "material_name": "Roche de vert-de-gris", "mining_label": "Creuse la roche de vert-de-gris", "drop_item": "rock", "seal": "copper_seal"},
	## Roches des six strates (2026-11-22) : 12 à 24 coups, chacune derrière le sceau de la strate (Catalog).
	"rock3": {"resistance": 12, "material_name": "Basalte des Forges", "mining_label": "Creuse le basalte", "drop_item": "rock", "seal": "iron_seal"},
	"rock4": {"resistance": 14, "material_name": "Roche noire", "mining_label": "Creuse la roche noire", "drop_item": "rock", "seal": "silver_seal"},
	"rock5": {"resistance": 16, "material_name": "Roche des rives", "mining_label": "Creuse la roche des rives", "drop_item": "rock", "seal": "limbo_seal"},
	"rock6": {"resistance": 18, "material_name": "Chair pétrifiée", "mining_label": "Perce la chair pétrifiée", "drop_item": "rock", "seal": "blood_seal"},
	"rock7": {"resistance": 20, "material_name": "Pierre tyrienne", "mining_label": "Taille la pierre tyrienne", "drop_item": "rock", "seal": "orichalcum_seal"},
	"rock8": {"resistance": 24, "material_name": "Maçonnerie de Byrsa", "mining_label": "Perce la maçonnerie", "drop_item": "rock", "seal": "gold_seal"},
	"silver": {"resistance": 4, "material_name": "Argent", "mining_label": "Mine l’argent", "drop_item": "silver"},
	"tear": {"resistance": 4, "material_name": "Larme de limbe", "mining_label": "Détache la larme", "drop_item": "tear"},
	"amber": {"resistance": 4, "material_name": "Ambre de sang", "mining_label": "Arrache l’ambre", "drop_item": "amber"},
	"orichalcum": {"resistance": 4, "material_name": "Orichalque", "mining_label": "Mine l’orichalque", "drop_item": "orichalcum"},
	"wood": {"resistance": 4, "material_name": "Arbre pétrifié", "mining_label": "Récolte le bois noir", "drop_item": "wood"},
}
const ITEMS := {
	"gold": {"name": "Or", "color": Color("#ddb457")},
	"quartz": {"name": "Quartz", "color": Color("#c5b5d8")},
	"iron": {"name": "Fer", "color": Color("#8796a2")},
	"copper": {"name": "Cuivre", "color": Color("#c47b58")},
	"rock": {"name": "Roche", "color": Color("#89969c")},
	"wood": {"name": "Bois noir", "color": Color("#9a7a52")},
	"silver": {"name": "Argent", "color": Color("#b8c2d0")},
	"tear": {"name": "Larme de limbe", "color": Color("#a9cfc0")},
	"amber": {"name": "Ambre de sang", "color": Color("#d07a2a")},
	"orichalcum": {"name": "Orichalque", "color": Color("#e09a78")},
}

## Ordre des colonnes des atlas de minerai (nodules.png, ore_faces.png ; tools/minerais/minerais_v4.py).
const ORES := ["copper", "iron", "quartz", "gold", "silver", "tear", "amber", "orichalcum"]

## Arbres pétrifiés : bosquets de 2 × 2 cases, inépuisables pour tous les mineurs depuis le 2026-11-20
## (WOOD_YIELD reste le bois de départ, que plus rien n'entame).
const WOOD := "wood"
const WOOD_YIELD := 20
const WOOD_KEEPER := "medeina"
