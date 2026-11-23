extends RefCounted
## Munitions de l'Arbalestrie, débloquées par la recherche « Arbalestrie modulaire » de la Bibliothèque
## (planche planches/arbalestrie-modulaire-planche.html, validée le 2026-11-19). Sans la recherche, seules les
## balles spirituelles existent. Aucune munition ne consomme de mana (2026-11-22) ;
## `cd_mult` : facteur de recharge (balles spirituelles : 6 tirs par seconde au lieu de 4) ; `mult` : facteur
## de dégâts par balle ; `count` / `spread` : balles par tir et demi-écart en degrés ; `heal` : PV que l'Ingénieur
## regagne par balle qui fait des dégâts (2026-11-21 : 1 PV, au lieu des dégâts faits) ; `splash` : rayon (unités) et `splash_mult` des dégâts autour de la cible ;
## `sfx` : son de tir propre à la munition (sinon « arbalestrie »).

const RESEARCH := "modular_crossbow"
const ORDER: Array[String] = ["spirit", "indra", "medeina", "sigil", "aether"]
const AMMO := {
	"spirit": {"name": "Balles spirituelles", "mult": 1.0, "cd_mult": 2.0 / 3.0,
		"desc": "Mode normal, cadence rapide : 6 balles par seconde"},
	"indra": {"name": "Balles d’Indra", "mult": 1.5, "sfx": "arbalestrie_indra",
		"desc": "Balle lourde, +50 % de dégâts par balle mais 4 tirs par seconde : perce mieux l’armure"},
	"medeina": {"name": "Balles de Medeina", "mult": 0.5, "heal": 1.0, "sfx": "arbalestrie_medeina",
		"desc": "−50 % de dégâts, chaque balle qui touche rend 1 PV"},
	"sigil": {"name": "Balles de Sigil", "mult": 0.7, "count": 2, "spread": 4.5, "sfx": "arbalestrie_sigil",
		"desc": "Deux balles par tir, −30 % chacune"},
	"aether": {"name": "Balles d’Aether", "mult": 1.0, "splash": 4.0, "splash_mult": 1.0 / 3.0, "sfx": "arbalestrie_aether",
		"desc": "Onde d’un bloc : un tiers des dégâts autour de la cible"},
}


## Son de tir de la munition `id`.
static func sound(id: String) -> String:
	return String(AMMO[id].get("sfx", "arbalestrie"))


static func unlocked() -> bool:
	return GameState.research_done.has(RESEARCH)


## Munition en service : la munition choisie si la recherche est faite, sinon les balles spirituelles.
static func current() -> String:
	return GameState.ammo if unlocked() and AMMO.has(GameState.ammo) else "spirit"


## Molette : munition suivante (`step` = ±1), en boucle.
static func cycle(step: int) -> void:
	var i := ORDER.find(current())
	select(ORDER[posmod(i + step, ORDER.size())])


## Change de munition en retenant la précédente (Barillet double) et l'instant (Culasse froide).
static func select(id: String) -> void:
	if id == current():
		return
	GameState.ammo_prev = current()
	GameState.ammo = id
	GameState.ammo_changed_at = GameState.sim_time
	GameState.barrel_flip = false
