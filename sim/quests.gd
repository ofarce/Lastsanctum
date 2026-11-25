class_name Quests
extends RefCounted
## Quêtes de l'Ingénieur, affichées par le panneau d'objectif (ObjectivePanel, « Rapport de l'Ingénieur »).
## Validation par lecture de l'état de la partie à chaque mise à jour du HUD. Ordre du 2026-11-22
## (planches/intro-capsule-planche.html) :
##   1. Réactiver l'Ancre : partie sans séquence d'ouverture seulement (l'Ancre s'y réveille à la main).
##   2. Sortir de la capsule : l'Ancre est allumée et l'Ingénieur est dehors.
##   3. Ouvrir le Coffre Antique : coffre ouvert (GameState.base_inventory_unlocked) ; il remet l'équipement et le plan.
##   4. Le plan « Analyse » : Établi d'exo achevé, mod Analyse fabriqué (au stock, dans un coffre rouge ou porté).
##   5. La Salamandre : démarre quand l'Ingénieur a perdu son armure (Unit.unarmored, vrai dès l'ouverture) ;
##      quatre autels indépendants, un par divinité (un deuxième temple de Sigil ne compte pas deux fois).
##   6. Âges des métaux (sim/ages.gd) : « Le secret du cuivre », puis « Le secret du fer » — miner le minerai,
##      vaincre le boss qui garde son savoir. Affichées tant qu'un âge reste à ouvrir.
##   7. Un mystérieux compagnon : annoncée « Bientôt ! », jamais active.
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
const ANALYSE_ITEM := "module_analyse"

## Quête en cours : anchor, capsule, chest, analyse, salamandre, companion ; "" avant la perte d'armure.
var quest := "anchor"
var altars := {}
var _altar_quote := ""
var _altar_quote_until := -INF


func reset() -> void:
	quest = "anchor"
	altars = {}
	_altar_quote = ""
	_altar_quote_until = -INF


## Valide ce qui peut l'être, dans l'ordre : une quête terminée lance aussitôt la suivante.
func update() -> void:
	var before := quest
	_advance()
	# Une quête vient de s'achever (le passage « » → salamandre n'en termine aucune).
	if quest != before and before != "":
		Sfx.play("quete")


func _advance() -> void:
	if quest == "anchor" and (GameState.orb_active or GameState.opening_stage != ""):
		quest = "capsule"
	if quest == "capsule" and GameState.orb_active and _engineer_out():
		quest = "chest"
	if quest == "chest" and GameState.base_inventory_unlocked:
		quest = "analyse"
	if quest == "analyse" and _etabli_built() and _analyse_made():
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
			quest = "companion"


## Objectif courant pour ObjectivePanel.push() ({} : aucun).
func objective() -> Dictionary:
	if GameState.ended:
		return {}
	# Le premier boss interrompt la quête en cours, qui reprend à sa chute.
	var boss := Martyre.objective()
	if not boss.is_empty():
		return boss
	boss = OeilMatrice.objective()
	if not boss.is_empty():
		return boss
	boss = Archipretre.objective()
	if not boss.is_empty():
		return boss
	boss = Eclusier.objective()
	if not boss.is_empty():
		return boss
	boss = Patine.objective()
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
		"capsule":
			return {"id": "capsule", "quest": "Sortir de la capsule", "label": "Sortir de la capsule (E)",
				"quote": "L’Ancre a rallumé la capsule. Je peux sortir.",
				"done_quote": "Un Coffre Antique, juste à côté. Et ses glyphes brillent."}
		"chest":
			return {"id": "chest", "quest": "Le Coffre Antique", "label": "Ouvrir le Coffre Antique",
				"quote": "Ce Coffre s’est rallumé avec l’Ancre. Voyons ce qu’il garde.",
				"done_quote": "De quoi me battre et creuser. Et un plan tyrien."}
		"analyse":
			var built := _etabli_built()
			var made := _analyse_made()
			return {"id": "analyse", "quest": "Le plan « Analyse »",
				"items": [{"label": "Construire l’Établi d’exo", "done": built}, {"label": "Fabriquer le mod Analyse", "done": made}],
				"step": "%d / 2" % (int(built) + int(made)),
				"quote": "Ce plan décrit un module d’exo. Il me faut un établi, des planches, de la fibre et de l’ichor.",
				"done_quote": "L’Analyse fonctionne : je vois enfin ce qu’il reste à mes ennemis."}
		"companion":
			# Le Coffre est ouvert : sa réplique de fin est jouée par le panneau au changement d'identifiant.
			var age := Ages.objective()
			if not age.is_empty():
				return age
			return {"id": "companion", "quest": "Un mystérieux compagnon", "soon": true,
				"quote": "Un animal ? Il est faible...", "label": "Bientôt !"}
	return {}


func _engineer_unarmored() -> bool:
	return GameState.units.any(func(u: Unit) -> bool: return u.role == "engineer" and u.unarmored)


func _engineer_out() -> bool:
	return not GameState.in_capsule and GameState.units.any(func(u: Unit) -> bool:
		return u.role == "engineer" and u.alive() and not u.hidden)


func _etabli_built() -> bool:
	return GameState.buildings.any(func(b: Building) -> bool: return b.type == "etabli" and b.complete)


## Mod Analyse obtenu : au stock (coffre de base, sac), dans le coffre rouge d'un bâtiment, ou porté par un Exilé.
func _analyse_made() -> bool:
	if preload("res://sim/item_storage.gd").count(ANALYSE_ITEM) > 0:
		return true
	if GameState.buildings.any(func(b: Building) -> bool: return Production.count_in(b.output_box, ANALYSE_ITEM) > 0):
		return true
	return GameState.units.any(func(u: Unit) -> bool: return u.equipment.values().has(ANALYSE_ITEM))
