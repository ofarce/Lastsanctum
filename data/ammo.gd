extends RefCounted
## Munitions de l'Arbalestrie, débloquées par la recherche « Arbalestrie modulaire » de la Bibliothèque
## (planche planches/arbalestrie-modulaire-planche.html, validée le 2026-11-19). Sans la recherche, seules les
## balles spirituelles existent. `cost` : mana prélevée à chaque tir (null = `mana` de l'arme, de chaque type) ;
## `cd_mult` : facteur de recharge (balles spirituelles : 6 tirs par seconde au lieu de 4) ; `mult` : facteur
## de dégâts par balle ; `count` / `spread` : balles par tir et demi-écart en degrés ; `heal` : l'Ingénieur
## regagne les dégâts réellement faits ; `splash` : rayon (unités) et `splash_mult` des dégâts autour de la cible.

const RESEARCH := "modular_crossbow"
const ORDER: Array[String] = ["spirit", "indra", "medeina", "sigil", "aether"]
const AMMO := {
	"spirit": {"name": "Balles spirituelles", "cost": null, "mult": 1.0, "cd_mult": 2.0 / 3.0,
		"desc": "Mode normal, cadence rapide : 6 balles par seconde", "cost_text": "0,5 de chaque mana par tir"},
	"indra": {"name": "Balles d’Indra", "cost": {"discipline": 2}, "mult": 1.5,
		"desc": "+50 % de dégâts", "cost_text": "2 Discipline par tir"},
	"medeina": {"name": "Balles de Medeina", "cost": {"vie": 2}, "mult": 0.5, "heal": true,
		"desc": "−50 % de dégâts, soigne de la valeur des dégâts faits", "cost_text": "2 Vie par tir"},
	"sigil": {"name": "Balles de Sigil", "cost": {"savoir": 2}, "mult": 0.7, "count": 2, "spread": 4.5,
		"desc": "Deux balles par tir, −30 % chacune", "cost_text": "2 Savoir par tir"},
	"aether": {"name": "Balles d’Aether", "cost": {"forge": 2}, "mult": 1.0, "splash": 4.0, "splash_mult": 0.25,
		"desc": "Onde d’un bloc : un quart des dégâts autour de la cible", "cost_text": "2 Forge par tir"},
}


static func unlocked() -> bool:
	return GameState.research_done.has(RESEARCH)


## Munition en service : la munition choisie si la recherche est faite, sinon les balles spirituelles.
static func current() -> String:
	return GameState.ammo if unlocked() and AMMO.has(GameState.ammo) else "spirit"


## Mana prélevée par un tir de `id` avec une arme qui coûte `base` de chaque mana (balles spirituelles).
static func cost(id: String, base: float) -> Dictionary:
	var c: Variant = AMMO[id]["cost"]
	if c == null:
		var out := {}
		for r: String in Catalog.RES_ORDER:
			out[r] = base
		return out
	return c


static func can_pay(id: String, base: float) -> bool:
	var c := cost(id, base)
	for r: String in c:
		if GameState.res[r] < float(c[r]):
			return false
	return true


static func pay(id: String, base: float) -> void:
	var c := cost(id, base)
	for r: String in c:
		GameState.res[r] -= float(c[r])


## Molette : munition suivante (`step` = ±1), en boucle.
static func cycle(step: int) -> void:
	var i := ORDER.find(current())
	GameState.ammo = ORDER[posmod(i + step, ORDER.size())]
