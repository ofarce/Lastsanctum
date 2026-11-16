class_name Enemy
extends Unit
## Ennemi (spawn, Index.html ; rejeton : updateEvilPortals, galleries.js, 73b410f). Le rôle porte le type
## (creep, spitter, brute, beast) pour le rendu.

## Ordres de groupe, uniquement pour les ennemis issus des vagues.
var tactical_group: Dictionary = {}
var tactical_role := ""
var tactical_slot := 0
var tactical_goal: Variant = null
var tactical_speed := 0.0
var tactical_target_id := -1
var tactical_target_until := -INF
var tactical_retreat := 0.0
var tactical_retreating := false
var tactical_last_hp := INF

var kind := ""
var speed := 0.0
var reach := 0.0
var damage := 0.0
var cooldown := 0.0
var stun := 0.0
var slow_until := 0.0
var beast := false
var armor := 0.0
var attack_started := -INF
var died_at := INF
## Portail maléfique d'origine (rejetons), ou null.
var portal: Variant = null


static func make(k: String, px: float, pz: float, cd: float, scaling: Dictionary = {}) -> Enemy:
	var e := Enemy.new()
	var E: Dictionary = Catalog.ENEMY[k]
	e.id = -1
	e.kind = k
	e.role = k
	e.x = px
	e.z = pz
	e.tx = px
	e.tz = pz
	e.hp = E["hp"] * scaling.get("hp", 1.0)
	e.tactical_last_hp = e.hp
	e.max_hp = e.hp
	e.speed = E["speed"]
	e.reach = E["range"]
	e.damage = E["damage"] * scaling.get("damage", 1.0)
	e.armor = E.get("armor", 0.0) + scaling.get("armor", 0.0)
	e.name = Catalog.ENEMY_INFO[k]["name"]
	e.cooldown = cd
	e.beast = k == "beast"
	return e


func is_enemy() -> bool:
	return true


## Clé d'animation au repos (u.id ?? Math.round(x·7 + z·13)) : les ennemis n'ont pas d'identifiant.
func anim_key() -> int:
	return int(floorf(x * 7.0 + z * 13.0 + 0.5))
