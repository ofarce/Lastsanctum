class_name Quests
extends RefCounted
## Quêtes de l'Ingénieur, affichées par le panneau d'objectif (ObjectivePanel, « Rapport de l'Ingénieur »).
## Validation par lecture de l'état de la partie à chaque mise à jour du HUD :
##   1. Réactiver l'Ancre : l'Ancre est restaurée (GameState.orb_active).
##   2. La Salamandre : démarre quand l'Ingénieur perd son armure (Unit.unarmored, surcharge de l'Ancre) ;
##      quatre autels indépendants, un par divinité (un deuxième temple de Sigil ne compte pas deux fois).
##   3. Le Coffre Antique : Sceau de Minage fabriqué (recherche mining_artifact), Ingénieur entré dans la
##      réserve scellée (CaveShape.in_vault), coffre ouvert (GameState.base_inventory_unlocked).
##   4. Un mystérieux compagnon : annoncée « Bientôt ! », jamais active.
## Objectif prioritaire : « Éliminer la Martyre de Byrsa en combat singulier » tant que le boss vit
## (sim/martyre.gd) ; il interrompt la quête affichée sans la valider.
## Chaque étape validée reste acquise, même si l'état qui l'a validée disparaît ensuite (temple détruit…).
## objective() rend le dictionnaire attendu par ObjectivePanel.push().

const DEITIES := ["sigil", "indra", "medeina", "aether"]
const ALTAR_LABELS := {"sigil": "Construire un autel à Sigil", "indra": "Construire un autel à Indra",
	"medeina": "Construire un autel à Medeina", "aether": "Construire un autel à Aether"}
const ALTAR_QUOTES := {
	"sigil": "Sigil veille. Ses érudits sauront ce que nous avons oublié.",
	"indra": "Indra répond. Ses guerriers tiendront la ligne.",
	"medeina": "Le cycle de Medeina reprend : la mort ne sera plus une fin.",
	"aether": "Aether lit le ciel pour nous. Les étoiles guideront la forge."}
## Durée d'affichage de la réplique d'un autel avant le retour à la réplique de la quête (s de simulation).
const ALTAR_QUOTE_TIME := 6.0
## Étapes du Coffre Antique : libellé, réplique, réplique une fois l'étape validée.
const CHEST_STEPS := [
	["Fabriquer un Sceau de Minage", "Ces murs ont été scellés par les miens. Il me faut un sceau pour les rouvrir.",
		"Ce sceau devrait ne faire qu’une bouchée de ces murs en pierre."],
	["Ouvrir un chemin vers le Coffre Antique", "Le Coffre Antique est quelque part derrière cette roche. Je dois creuser jusqu’à lui.",
		"Le voilà. Intact, après tout ce temps."],
	["Ouvrir le Coffre Antique", "Il ne reste qu’à l’ouvrir.",
		"De quoi stocker nos réserves. Le sanctuaire peut enfin s’organiser."]]

## Quête en cours : anchor, salamandre, chest, companion ; "" entre l'Ancre et la perte d'armure.
var quest := "anchor"
var altars := {}
var chest_step := 0
var _altar_quote := ""
var _altar_quote_until := -INF


func reset() -> void:
	quest = "anchor"
	altars = {}
	chest_step = 0
	_altar_quote = ""
	_altar_quote_until = -INF


## Valide ce qui peut l'être, dans l'ordre : une quête terminée lance aussitôt la suivante.
func update() -> void:
	if quest == "anchor" and GameState.orb_active:
		quest = ""
	if quest == "" and _engineer_unarmored():
		quest = "salamandre"
	if quest == "salamandre":
		for b: Building in GameState.buildings:
			if b.complete and b.type in DEITIES and not altars.has(b.type):
				altars[b.type] = true
				_altar_quote = ALTAR_QUOTES[b.type]
				_altar_quote_until = GameState.sim_time + ALTAR_QUOTE_TIME
		if altars.size() == DEITIES.size():
			quest = "chest"
			chest_step = 0
	if quest == "chest":
		if chest_step == 0 and GameState.research_done.has("mining_artifact"):
			chest_step = 1
		if chest_step == 1 and _engineer_in_vault():
			chest_step = 2
		if chest_step == 2 and GameState.base_inventory_unlocked:
			quest = "companion"


## Objectif courant pour ObjectivePanel.push() ({} : aucun).
func objective() -> Dictionary:
	if GameState.ended:
		return {}
	# Le premier boss interrompt la quête en cours, qui reprend à sa chute.
	var boss := Martyre.objective()
	if not boss.is_empty():
		return boss
	match quest:
		"anchor":
			var p := clampf(GameState.orb_progress / Simulation.ORB_TIME, 0.0, 1.0)
			return {"id": "anchor", "quest": "Réactiver l’Ancre", "label": "Réactiver l’Ancre",
				"quote": "L’Ancre s’est éteinte. Je dois la réactiver : elle réveillera les gardes de l’entrée.",
				"done_quote": "L’Ancre respire de nouveau. Les gardes se lèvent.",
				"value": "%d %%" % roundi(p * 100.0) if p > 0.0 else "", "progress": p}
		"salamandre":
			var items: Array[Dictionary] = []
			for d: String in DEITIES:
				items.append({"label": ALTAR_LABELS[d], "done": altars.has(d)})
			var recent := GameState.sim_time < _altar_quote_until
			return {"id": "salamandre", "quest": "La Salamandre", "items": items,
				"step": "%d / %d" % [altars.size(), DEITIES.size()],
				"quote": _altar_quote if recent else "Mon exosquelette est mort. Par l’Énonciation, je dois rappeler les quatre cultes.",
				"done_quote": "Les quatre cultes sont rappelés. La Salamandre va m’écouter."}
		"chest":
			var s: Array = CHEST_STEPS[chest_step]
			return {"id": "chest_%d" % chest_step, "quest": "Le Coffre Antique", "label": s[0],
				"step": "%d / %d" % [chest_step + 1, CHEST_STEPS.size()], "quote": s[1], "done_quote": s[2],
				"progress": float(chest_step) / CHEST_STEPS.size()}
		"companion":
			# Le Coffre est ouvert : sa réplique de fin est jouée par le panneau au changement d'identifiant.
			return {"id": "companion", "quest": "Un mystérieux compagnon", "soon": true,
				"quote": "Un animal ? Il est faible...", "label": "Bientôt !"}
	return {}


func _engineer_unarmored() -> bool:
	return GameState.units.any(func(u: Unit) -> bool: return u.role == "engineer" and u.unarmored)


func _engineer_in_vault() -> bool:
	return GameState.units.any(func(u: Unit) -> bool:
		return u.role == "engineer" and u.alive() and not u.hidden and CaveShape.in_vault(u.x, u.z))
