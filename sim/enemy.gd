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
## Cadence des vagues (Catalog.WAVE_PACE) : déplacement et animations accélérés d'autant.
var pace := 1.0
var reach := 0.0
var damage := 0.0
var cooldown := 0.0
var stun := 0.0
var slow_until := 0.0
var beast := false
var armor := 0.0
var attack_started := -INF
## Coup annoncé (Catalog.ENEMY_WINDUP) : durée de l'armement de l'attaque en cours (0 = coup immédiat), instant où
## le coup tombera (INF = rien en attente) et sa cible (null = l'Ancre).
var windup := 0.0
var strike_at := INF
var strike_target: Unit = null
## Tir annoncé sur l'Exilé incarné (EnemyShots) : point visé à l'annonce, null sinon.
var shot_aim: Variant = null
## Chien de la Bête : instant du prochain crachat de feu (EnemyShots.spit) ; -INF = pas encore tiré au sort.
var spit_at := -INF
## Crachat annoncé (EnemyShots.SPIT.warn) : instant du départ (INF = rien en attente) et cible visée.
var spit_fire_at := INF
var spit_target: Unit = null
## Crachat annoncé sur l'Ancre (pas de cible vivante).
var spit_core := false
## Strazhar : point où a été fiché le dernier éclat de son sillage (EnemyShots.BONE), et instant de la pose ;
## null = pas de course en cours près de l'Exilé incarné.
var trail_from: Variant = null
var trail_t := 0.0
## Prime sans touche (Loot.FLAWLESS) : l'Exilé a frappé ce boss ; l'Exilé a été touché pendant qu'il le combattait.
var engineer_hit := false
var touched_engineer := false
## Incantation (sceaux) et réaction aux coups de la Martyre de Byrsa : début des animations martyre_cast, martyre_hit.
var cast_started := -INF
var hurt_at := -INF
var died_at := INF
## Envoûté jusqu'à cet instant (sim/mages.gd) : son armure est abaissée.
var hexed_until := -INF
## Butin resté sur le corps (sim/loot.gd) : identifiants d'objets ; vide = rien à fouiller.
var loot: Array[String] = []
## Nom de celui qui portait les armes et armures de ce butin (Loot.NAMES), "" s'il n'en porte pas.
var bearer := ""
## Faune hostile de la jungle (sim/wildlife.gd) : neutre, repaire, proie courante.
var neutral := false
var home := Vector2.ZERO
var wild_target: Unit = null
## Portail maléfique d'origine (rejetons), ou null.
var portal: Variant = null
## Pylône de Merenor gardé (sim/pylons.gd), ou null ; alpha de la meute ; instant de sa renaissance.
var pylon: Variant = null
var alpha := false
var risen_at := -INF
## Tanière du groupe errant des galeries (sim/roamers.gd), ou null.
var roam: Variant = null
## Meute nocturne lâchée par un pylône (sim/night.gd) : marche sur l'Ancre, hors menace et fin de vague.
var raid := false


static func make(k: String, px: float, pz: float, cd: float, scaling: Dictionary = {}) -> Enemy:
	var e := Enemy.new()
	var E: Dictionary = Catalog.ENEMY[k]
	e.id = -1
	e.kind = k
	# Rôle = planche de sprites : un type sans planche emprunte celle d'un autre (clé « art »).
	e.role = E.get("art", k)
	e.x = px
	e.z = pz
	e.tx = px
	e.tz = pz
	e.hp = E["hp"] * scaling.get("hp", 1.0)
	e.tactical_last_hp = e.hp
	e.max_hp = e.hp
	e.speed = E["speed"] * (Catalog.CREDO_SPEED if Catalog.CREDO_KINDS.has(k) else 1.0)
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


## Silhouettes des ennemis (hitboxes), en unités de monde, mesurées sur les planches (assets/imported/enemies,
## pixels opaques des animations de repos et de marche ; 8 px natifs par unité) : demi-largeur, hauteur du sprite
## au-dessus des pieds (projetée au sol vers le nord, comme Proj.nat), marge sous les pieds, et allonge en plus
## de la mêlée (corps large : on le frappe dès son bord). Les boss gardent la leur (Martyre.BODY, OeilMatrice.BODY).
## Un alpha des Pylônes (dessiné Pylons.ALPHA fois plus grand) a une silhouette agrandie d'autant.
const BODY := {
	"creep": {"half_w": 1.15, "top": 4.0, "foot": 0.5, "melee": 0.0},
	"spitter": {"half_w": 1.15, "top": 4.0, "foot": 0.5, "melee": 0.0},
	# Colosse cuirassé (tools/unites-maj/export_g1.py) : corps et épaulières, sans les poings écartés.
	"brute": {"half_w": 2.4, "top": 4.5, "foot": 0.5, "melee": 0.4},
	"beast": {"half_w": 2.0, "top": 2.5, "foot": 0.5, "melee": 0.4},
	"scout": {"half_w": 0.9, "top": 3.9, "foot": 0.5, "melee": 0.0},
	"soldier": {"half_w": 0.9, "top": 4.0, "foot": 0.5, "melee": 0.0},
	"shield": {"half_w": 1.0, "top": 4.0, "foot": 0.5, "melee": 0.0},
	"archer": {"half_w": 1.2, "top": 3.9, "foot": 0.5, "melee": 0.0},
	# Squelettes de la nuit (tools/squelettes/export.py) : os fins, la lame du collier n'est pas comptée.
	"skeleton": {"half_w": 0.8, "top": 3.9, "foot": 0.5, "melee": 0.0},
	"skeleton_bubo": {"half_w": 1.0, "top": 3.9, "foot": 0.5, "melee": 0.0},
	"skeleton_bomb": {"half_w": 0.8, "top": 3.9, "foot": 0.5, "melee": 0.0},
	# Champion couronné, à quatre pattes dans toutes ses animations (cadre 68 × 48, export_g1.py).
	"strazhar": {"half_w": 3.1, "top": 4.2, "foot": 0.5, "melee": 0.8},
	# Faune du biome 2 (tools/biomes-persos/export_monstres.py). La chauve-souris vole : sa silhouette monte jusqu'à elle.
	"tick": {"half_w": 1.6, "top": 2.4, "foot": 0.5, "melee": 0.2},
	"bat": {"half_w": 2.0, "top": 4.6, "foot": 0.5, "melee": 0.2},
	"eel": {"half_w": 3.4, "top": 2.2, "foot": 0.8, "melee": 0.6},
	"croc": {"half_w": 2.75, "top": 1.6, "foot": 0.5, "melee": 0.9},
	"feline": {"half_w": 2.1, "top": 2.3, "foot": 0.5, "melee": 0.4},
}
## Allonge de mêlée de base, comptée pour tout ennemi (Combat.gear_attack) : un corps humain.
const MELEE_BASE := 0.6


## Silhouette de cet ennemi (voir BODY), à l'échelle de l'alpha.
func body() -> Dictionary:
	var b: Dictionary = Martyre.BODY if kind == Martyre.KIND else OeilMatrice.BODY if kind == OeilMatrice.KIND \
		else OeilMatrice.PUPIL_BODY if kind == OeilMatrice.PUPIL_KIND else Gorge.BODY if kind == Gorge.KIND else BODY.get(kind, BODY["creep"])
	if not alpha:
		return b
	var s := Pylons.ALPHA
	return {"half_w": b["half_w"] * s, "top": b["top"] * s, "foot": b["foot"] * s,
		"melee": (MELEE_BASE + b["melee"]) * s - MELEE_BASE}


## Rectangle au sol couvert par la silhouette (x de gauche à droite, z du sommet du sprite à sous les pieds).
func body_rect() -> Rect2:
	var b := body()
	return Rect2(x - b["half_w"], z - b["top"], 2.0 * b["half_w"], b["top"] + b["foot"])


## Allonge supplémentaire pour frapper cet ennemi au corps à corps.
func melee_body() -> float:
	return float(body()["melee"])


## Distance le long du rayon (from, d normalisé) à laquelle il entre dans la silhouette, ou INF (0 si from y est).
func ray_hit(from: Vector2, d: Vector2) -> float:
	var r := body_rect()
	var t0 := 0.0
	var t1 := INF
	for axis in 2:
		var o := from[axis]
		var v := d[axis]
		var lo := r.position[axis]
		var hi := r.end[axis]
		if absf(v) < 1e-6:
			if o < lo or o > hi:
				return INF
			continue
		var a := (lo - o) / v
		var b := (hi - o) / v
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	return t0 if t0 <= t1 else INF
