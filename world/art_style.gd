class_name ArtStyle
extends RefCounted
## Style des blocs de la montagne : « Ardoise tyrienne » (planche caverne-propositions, choix 1).
## Les images sont produites par tools/ardoise/ardoise.py à partir de celles du baker, qui restent
## intactes dans res://assets/baked/ (références de parité avec le prototype).

const ROOT := "res://assets/ardoise/world/"
## Sol complet (16 blocs de 1024², mêmes dimensions et origine que le sol du baker).
const GROUND := ROOT + "ground/ground_r%d_c%d.png"
## Textures périodiques (PERIOD px), lues en coordonnées absolues du sol.
const TILES := ROOT + "tiles/"
const PERIOD := 504
const ATLAS := ROOT + "decor_atlas.png"
const RUNTIME := ROOT + "runtime/"
const PALETTE := "res://assets/ardoise/palette.json"
## Lumière des grappes de quartz laiteux : blanc froid (le cyan reste réservé aux Exilés).
const QUARTZ_LIGHT := Color8(200, 212, 236)
