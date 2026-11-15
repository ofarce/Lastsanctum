class_name Wind
## Brise du décor (assets/wind.js). Deux ondes spatiales lentes : une même brise traverse
## la jungle sans synchroniser les arbres. Le shader res://shaders/world_sprite.gdshader
## reproduit exactement la même formule.

## Amplitude et hauteur de référence par type d'arbre (WIND_TREES, wind.js:2).
const TREES := {
	"big": {"amplitude": 1.5, "height": 40.0},
	"cyp": {"amplitude": 1.05, "height": 48.0},
	"palm": {"amplitude": 2.2, "height": 44.0},
	"bush": {"amplitude": 0.65, "height": 7.0},
}


static func at(x: float, z: float, t: float) -> float:
	var phase := x * 0.047 + z * 0.031
	return sin(t * 1.05 - phase) * 0.72 + sin(t * 1.83 + phase * 1.7) * 0.28


## Cisaillement horizontal du feuillage (drawWindTree, wind.js:34).
static func shear(kind: String, x: float, z: float, t: float) -> float:
	var spec: Dictionary = TREES[kind]
	return -at(x, z, t) * spec["amplitude"] / spec["height"]
