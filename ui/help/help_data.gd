class_name HelpData
extends RefCounted
## Textes du codex d'aide (ui/help/help_panel.gd, planche planches/aide-propositions.html).
## Tout le contenu est ici : corriger un texte ne demande pas de toucher au panneau.
##
## Une page = {id, icon (HudStyle.icon), name (onglet), title, lore (phrase en italique), blocks}.
## `locked` : la page reste cadenassée tant qu'aucun Pylône de Merenor n'a été approché.
## Blocs :
##   {"keys": [[titre, [[jetons, texte], …]], …]}   groupes de raccourcis, sur deux colonnes
##   {"strip": [icône, titre, jetons]}              bandeau d'une ligne
##   {"cards": [[icône ou "", titre, texte], …]}    cartes côte à côte
##   {"table": {"head": […], "rows": [[…], …]}}     tableau
##   {"list": [texte, …]}                           liste à puces
## Jetons : "Z" = touche ; "@L", "@R", "@W" = clic gauche, clic droit, molette ; "~texte" = texte simple.

const TABS := [
	{
		"id": "cmd", "icon": "move", "name": "Commandes", "title": "Commandes",
		"lore": "Clavier AZERTY. Les touches des boutons sont écrites sur les boutons.",
		"blocks": [
			{"keys": [
				["Caméra", [
					[["Z", "Q", "S", "D"], "Déplacer la vue (ou les flèches)"],
					[["@W", "~molette"], "Zoomer et dézoomer"],
				]],
				["Sélection", [
					[["@L", "~clic"], "Sélectionner une unité, un bâtiment"],
					[["@L", "~glisser"], "Cadre de sélection"],
					[["1", "~…", "9"], "Sélectionner une unité"],
					[["Ctrl", "~+", "A"], "Tout sélectionner"],
				]],
				["Ordres", [
					[["@R", "~clic"], "Aller, attaquer, prier, canaliser"],
					[["@R", "~glisser"], "Marquer la roche à miner"],
					[["B", "~puis lettre"], "Construire un bâtiment"],
					[["P", "~puis lettre"], "Poser une défense"],
				]],
				["Raccourcis", [
					[["E"], "Entrer ou sortir de la capsule"],
					[["C"], "Inventaire de l’Ingénieur"],
					[["Tab", "~ou", "M"], "Grande carte (après recherche)"],
					[["Échap"], "Annuler, fermer un menu"],
					[["Maj", "~+", "R"], "Nouvelle partie"],
				]],
			]},
			{"strip": ["boot", "Incarné", ["Z", "Q", "S", "D", "~marcher  ·", "@R", "~tirer  ·", "@W", "~changer de munition  ·", "Ctrl", "~+", "@W", "~zoom"]]},
		],
	},
	{
		"id": "bases", "icon": "flame", "name": "Bases", "title": "Tenir le sanctuaire",
		"lore": "« Tant qu’elle demeure, le serment tient. »",
		"blocks": [
			{"cards": [
				["flame", "L’Ancre", "Le cœur du sanctuaire. La rallumer réveille les gardes de l’entrée. Si elle tombe, la partie est perdue."],
				["people", "Les quatre cultes", "Chaque autel attire des adeptes. Ils prient, bâtissent et travaillent. Sans eux, rien ne tourne."],
				["skull", "Les vagues", "Les ennemis arrivent par escouades ordonnées. Le compteur en haut à gauche annonce la suivante."],
			]},
			{"list": [
				"Le panneau d’objectif, sous la vague, indique toujours la prochaine étape.",
				"La Menace monte à mesure que le sanctuaire s’étend : plus elle est haute, plus les assauts sont durs.",
				"Le jour et la nuit se suivent. L’heure s’affiche sous les ressources.",
			]},
		],
	},
	{
		"id": "eco", "icon": "people", "name": "Adeptes", "title": "Ressources et adeptes",
		"lore": "Un adepte prie, ou travaille. Jamais les deux.",
		"blocks": [
			{"table": {"head": ["Culte", "Mana produit", "Bâtiments qu’il sert"], "rows": [
				["Aether", "Forge", "Atelier, Scierie, Archerie, Fonderie, Armurerie, mineurs"],
				["Sigil", "Savoir", "Bibliothèque"],
				["Medeina", "Vie", "Puits, Chambre"],
				["Indra", "Discipline", "Caserne"],
			]}},
			{"list": [
				"Un bâtiment ne fonctionne qu’avec au moins un adepte au poste. Jusqu’à cinq : chacun accélère le travail.",
				"Le bâtiment puise ses ingrédients dans les coffres et y range ce qu’il produit.",
				"Tous les coffres (bleus, rouges et Coffre Antique) forment un seul réseau de stockage infini, accessible partout.",
				"Les mineurs d’Aether creusent les filons et rapportent le minerai par lots de cinq.",
			]},
		],
	},
	{
		"id": "build", "icon": "hammer", "name": "Bâtiments", "title": "Bâtiments et fabrication",
		"lore": "B ouvre le menu de construction. Un adepte en prière vient bâtir le chantier.",
		"blocks": [
			{"table": {"head": ["Bâtiment", "À quoi il sert"], "rows": [
				["Temples", "Les adeptes y prient et produisent le mana de leur culte."],
				["Atelier · Scierie · Archerie", "Outils et défenses ; fibre de bois ; arcs et flèches."],
				["Fonderie · Armurerie", "Lingots ; armes et armures faites de lingots. Chacun fabrique en boucle la recette choisie."],
				["Bibliothèque", "Recherches : grande carte, Arbalestrie modulaire."],
				["Caserne", "Entraîne les soldats. Chaque soldat réclame son jeu d’armes."],
				["Puits · Chambre", "Soins et résurrection."],
			]}},
			{"strip": ["hammer", "Fabriquer", ["~Sélectionner le bâtiment, choisir un objet : nom et coût s’affichent au survol du bouton."]]},
		],
	},
	{
		"id": "fight", "icon": "sword", "name": "Combat", "title": "Combat et défenses",
		"lore": "P ouvre le menu des défenses à poser.",
		"blocks": [
			{"cards": [
				["", "Poste de tir", "Double la portée des tireurs placés tout près."],
				["", "Barricade", "Bloque le passage. Refusée si elle ferme le chemin de l’Ancre."],
				["", "Chausse-trappe", "Blesse en continu tout ennemi qui la traverse."],
			]},
			{"list": [
				"Les soldats attaquent seuls ce qui approche. Un clic droit sur un ennemi force la cible.",
				"L’Arbalestrie de l’Ingénieur charge cinq munitions une fois la recherche faite. Le barillet montre celle qui est engagée.",
				"Chaque tir spécial coûte du mana du culte correspondant.",
			]},
		],
	},
	{
		"id": "inc", "icon": "boot", "name": "Incarnation", "title": "Incarner un Exilé",
		"lore": "Descendre sur le terrain, puis reprendre de la hauteur.",
		"blocks": [
			{"keys": [
				["Entrer", [
					[["~Portrait"], "Survoler un Exilé de la galerie, puis « Incarner »"],
					[["E"], "Sortir de la capsule"],
				]],
				["Sortir", [
					[["E"], "Rejoindre la capsule : c’est le seul moyen"],
					[["~Mort"], "La chute de l’Exilé désincarne d’office"],
				]],
			]},
			{"list": [
				"La caméra suit l’Exilé. Z, Q, S, D le déplacent, le clic droit tire là où pointe la souris.",
				"L’inventaire de l’Ingénieur s’ouvre avec C : armure, arme, sac.",
				"Sans exosquelette, l’Ingénieur est fragile. Mieux vaut rentrer à la capsule que tomber.",
			]},
		],
	},
	{
		"id": "world", "icon": "flag", "name": "Monde", "title": "Au-delà du sanctuaire", "locked": true,
		"lore": "Le monde s’étend vers le nord, biome après biome.",
		"blocks": [
			{"cards": [
				["rune", "Pylônes de Merenor", "Une meute veille autour, menée par un alpha. Tuée, elle renaît en une minute."],
				["", "Corruption", "La nappe noire ronge l’Ingénieur tant qu’il y reste. Les adeptes y sont insensibles."],
				["spirit", "Canaliser", "Un esprit de chaque culte en prière autour du pylône le fait taire. S’il en manque un, le cycle reprend."],
			]},
			{"list": [
				"E au contact du socle : l’Ingénieur bénit le pylône et retarde les renaissances.",
				"La roche se creuse avec le Sceau de Minage. Les passages font toujours deux blocs de large.",
				"Chaque frontière de biome est gardée. La porte ne s’ouvre qu’après le gardien.",
			]},
		],
	},
]

const LOCKED_NAME := "À découvrir"
const LOCKED_TEXT := "Cette page s’écrira à la découverte du premier pylône."
