window.SONS = [
 {
  "id": "victoire",
  "cat": "Référence",
  "elem": "Obtention (Arbalestrie, Combinaison)",
  "hook": "sim/capsule.gd · déjà en jeu",
  "desc": "Le son validé : la mineur, quinte à vide tenue. Sert d'étalon de ton pour tout le reste.",
  "db": -8,
  "dur": 2.2
 },
 {
  "id": "ui_clic",
  "cat": "Interface",
  "elem": "Clic sur un bouton du HUD",
  "hook": "ui/hud · bouton pressé",
  "desc": "Une seule note aiguë très courte, filtrée. Doit disparaître sous le jeu.",
  "db": -16,
  "dur": 0.05
 },
 {
  "id": "ui_selection",
  "cat": "Interface",
  "elem": "Sélection d'une unité ou d'un bâtiment",
  "hook": "ui/input · sélection",
  "desc": "Deux notes montantes en quinte, plus douces que le clic.",
  "db": -14,
  "dur": 0.12
 },
 {
  "id": "ui_ordre",
  "cat": "Interface",
  "elem": "Ordre de déplacement / d'attaque",
  "hook": "ui/input · clic droit",
  "desc": "Petit glissement descendant, comme un pointeur qui se pose.",
  "db": -16,
  "dur": 0.07
 },
 {
  "id": "ui_refus",
  "cat": "Interface",
  "elem": "Action refusée (ressources, emplacement)",
  "hook": "placeables.gd / building.gd · « why »",
  "desc": "Seconde mineure descendante : on comprend « non » sans buzzer.",
  "db": -12,
  "dur": 0.26
 },
 {
  "id": "ui_banniere",
  "cat": "Interface",
  "elem": "Ouverture de la bannière bleue",
  "hook": "ui/banner · SnesBanner",
  "desc": "Carillon de quinte qui s'éteint en écho. Annonce sans interrompre.",
  "db": -14,
  "dur": 0.7
 },
 {
  "id": "ui_texte",
  "cat": "Interface",
  "elem": "Défilement du texte de dialogue",
  "hook": "ui/dialogue · par mot ou groupe",
  "desc": "Trois blips à pulsation étroite. À jouer tous les 3 ou 4 caractères, pas à chaque lettre.",
  "db": -22,
  "dur": 0.12
 },
 {
  "id": "ui_inventaire",
  "cat": "Interface",
  "elem": "Ouverture de l'inventaire / d'un coffre",
  "hook": "Events.inventory_requested",
  "desc": "Froissement de tissu court et une note sourde.",
  "db": -14,
  "dur": 0.2
 },
 {
  "id": "bat_pose",
  "cat": "Base",
  "elem": "Pose d'un bâtiment (chantier)",
  "hook": "building.gd · placement validé",
  "desc": "Bruit sourd de pierre posée, sans basse lourde.",
  "db": -10,
  "dur": 0.2
 },
 {
  "id": "bat_chantier",
  "cat": "Base",
  "elem": "Construction en cours",
  "hook": "building.gd · boucle pendant « time »",
  "desc": "Trois coups de marteau métalliques. Se joue en boucle espacée, à faible volume.",
  "db": -18,
  "dur": 0.95
 },
 {
  "id": "bat_termine",
  "cat": "Base",
  "elem": "Bâtiment terminé",
  "hook": "building.gd · fin de construction",
  "desc": "Quarte montante mi–la, la tenue. Plus courte et plus discrète que « victoire ».",
  "db": -10,
  "dur": 1.1
 },
 {
  "id": "priere",
  "cat": "Base",
  "elem": "Prière d'un adepte (ressource gagnée)",
  "hook": "production.gd · gain de ressource",
  "desc": "Deux tintements très aigus et feutrés. Fréquent : il doit rester presque inaudible.",
  "db": -24,
  "dur": 0.6
 },
 {
  "id": "recherche",
  "cat": "Base",
  "elem": "Recherche terminée (Bibliothèque…)",
  "hook": "Catalog.RESEARCH · achèvement",
  "desc": "Arpège mi mineur mi–sol–si puis mi aigu. Cousin de « victoire ».",
  "db": -9,
  "dur": 1.4
 },
 {
  "id": "forge",
  "cat": "Base",
  "elem": "Fabrication à la Forge / au Creuset",
  "hook": "production.gd · recette terminée",
  "desc": "Un coup d'enclume suivi d'un souffle de trempe.",
  "db": -12,
  "dur": 0.7
 },
 {
  "id": "coffre",
  "cat": "Base",
  "elem": "Dépôt / retrait dans un coffre",
  "hook": "item_storage.gd · transfert",
  "desc": "Loquet, couvercle de bois, loquet.",
  "db": -14,
  "dur": 0.3
 },
 {
  "id": "minage",
  "cat": "Base",
  "elem": "Mineur au filon",
  "hook": "production.gd · coup de pioche",
  "desc": "Deux coups de pioche sur roche, éclats de gravier.",
  "db": -18,
  "dur": 0.8
 },
 {
  "id": "objet_pose",
  "cat": "Base",
  "elem": "Pose d'une barricade / poste de tir",
  "hook": "placeables.gd · place()",
  "desc": "Bois et terre tassés, bref.",
  "db": -12,
  "dur": 0.25
 },
 {
  "id": "chausse_trapes",
  "cat": "Base",
  "elem": "Chausse-trapes posées ou piétinées",
  "hook": "placeables.gd · caltrops",
  "desc": "Petits cliquetis de fer éparpillés.",
  "db": -14,
  "dur": 0.3
 },
 {
  "id": "adepte_arrive",
  "cat": "Base",
  "elem": "Nouvel adepte / unité formée",
  "hook": "Caserne, Puits des Âmes · formation",
  "desc": "Glissando doux puis une note : quelqu'un rejoint les Exilés.",
  "db": -12,
  "dur": 0.9
 },
 {
  "id": "epee",
  "cat": "Exilés",
  "elem": "Frappe d'épée (Lame, Ingénieur, Templier)",
  "hook": "combat.gd · coup de mêlée",
  "desc": "Fouet d'air puis impact mat. Pas de « clang » : sinon trop chargé en mêlée.",
  "db": -14,
  "dur": 0.2
 },
 {
  "id": "moulinet",
  "cat": "Exilés",
  "elem": "Moulinet d'orage (Lame, 3e frappe)",
  "hook": "combat.gd · MOULINET",
  "desc": "Tourbillon d'air pulsé terminé par une crépitation électrique.",
  "db": -11,
  "dur": 0.75
 },
 {
  "id": "arc",
  "cat": "Exilés",
  "elem": "Tir à l'arc (archer, garde, Indra)",
  "hook": "combat.gd · ARROW_ROLES",
  "desc": "Corde qui vibre et souffle de la flèche.",
  "db": -15,
  "dur": 0.22
 },
 {
  "id": "fleche_impact",
  "cat": "Exilés",
  "elem": "Flèche qui touche",
  "hook": "combat.gd · impact projectile",
  "desc": "Toc sec et court. Partagé avec les flèches ennemies.",
  "db": -18,
  "dur": 0.12
 },
 {
  "id": "flammes",
  "cat": "Exilés",
  "elem": "Lance-flammes (en continu)",
  "hook": "combat.gd · flammes « continuous »",
  "desc": "Souffle grave modulé, quelques crépitements. Boucle tant que l'adepte tire.",
  "db": -16,
  "dur": 1.0
 },
 {
  "id": "flammes_mort",
  "cat": "Exilés",
  "elem": "Explosion à la mort du lance-flammes",
  "hook": "Catalog.FLAME_DEATH",
  "desc": "Détonation étouffée et bouffée de feu.",
  "db": -9,
  "dur": 1.0
 },
 {
  "id": "charge",
  "cat": "Exilés",
  "elem": "Charge (du Lac, au contact)",
  "hook": "Catalog.CHARGE",
  "desc": "Ruée qui monte puis heurt.",
  "db": -11,
  "dur": 0.65
 },
 {
  "id": "sillon",
  "cat": "Exilés",
  "elem": "Sillon de feu",
  "hook": "Catalog.SILLON",
  "desc": "Trait de feu qui se dépose au sol en descendant.",
  "db": -12,
  "dur": 0.7
 },
 {
  "id": "soin",
  "cat": "Exilés",
  "elem": "Soin (guérisseur)",
  "hook": "combat.gd · healer",
  "desc": "Arpège la mineur aigu, très doux, en écho.",
  "db": -15,
  "dur": 0.9
 },
 {
  "id": "tourelle",
  "cat": "Exilés",
  "elem": "Tir de tourelle",
  "hook": "Catalog.TURRET · bolt",
  "desc": "Zap descendant à pulsation, plus mécanique que magique.",
  "db": -14,
  "dur": 0.35
 },
 {
  "id": "exile_blesse",
  "cat": "Exilés",
  "elem": "Un Exilé est touché",
  "hook": "combat.gd · dégâts sur unité alliée",
  "desc": "Petit son descendant étouffé. Limité à un toutes les 0,3 s.",
  "db": -18,
  "dur": 0.2
 },
 {
  "id": "exile_mort",
  "cat": "Exilés",
  "elem": "Mort d'un Exilé",
  "hook": "unit.gd · mort",
  "desc": "Trois notes descendantes mi–do–la : sobre, sans drame.",
  "db": -10,
  "dur": 1.3
 },
 {
  "id": "niveau",
  "cat": "Exilés",
  "elem": "Montée de niveau (XP)",
  "hook": "Catalog.KILL_XP · palier",
  "desc": "Quinte la–mi et poussière brillante.",
  "db": -11,
  "dur": 1.0
 },
 {
  "id": "pilum",
  "cat": "Credo et Byrsa",
  "elem": "Pilum lancé (soldat du Credo)",
  "hook": "combat.gd · ENEMY_PILUM",
  "desc": "Sifflement d'air lourd puis pointe métallique.",
  "db": -14,
  "dur": 0.4
 },
 {
  "id": "sort_lumiere",
  "cat": "Credo et Byrsa",
  "elem": "Sort de lumière (Thuriféraire)",
  "hook": "combat.gd · ENEMY_STAFF",
  "desc": "Note vitreuse qui tremble et descend : lumière souillée.",
  "db": -14,
  "dur": 0.45
 },
 {
  "id": "automate",
  "cat": "Credo et Byrsa",
  "elem": "Coup de l'automate doré",
  "hook": "combat.gd · brute",
  "desc": "Clang lourd d'or fêlé (partiels inharmoniques), pas de sub-basse.",
  "db": -12,
  "dur": 0.6
 },
 {
  "id": "bouclier_dore",
  "cat": "Credo et Byrsa",
  "elem": "Coup bloqué par le bouclier doré",
  "hook": "combat.gd · armure absorbe",
  "desc": "« Ting » métallique clair. Signale que l'attaque est inefficace.",
  "db": -14,
  "dur": 0.5
 },
 {
  "id": "fanatique",
  "cat": "Credo et Byrsa",
  "elem": "Fanatique / soldat qui attaque",
  "hook": "combat.gd · creep, scout",
  "desc": "Râle bref, voix filtrée à pulsation.",
  "db": -18,
  "dur": 0.35
 },
 {
  "id": "aberration",
  "cat": "Credo et Byrsa",
  "elem": "Cri d'aberration du Dévoreur",
  "hook": "simulation.gd · apparition de portail",
  "desc": "Gargouillis humide haché. Rare, pour qu'il reste dérangeant.",
  "db": -14,
  "dur": 0.5
 },
 {
  "id": "ennemi_mort",
  "cat": "Credo et Byrsa",
  "elem": "Mort d'un ennemi",
  "hook": "enemy.gd · mort",
  "desc": "Bouffée sourde et petite chute. Très fréquent : volume bas.",
  "db": -18,
  "dur": 0.4
 },
 {
  "id": "strazhar",
  "cat": "Credo et Byrsa",
  "elem": "Arrivée du Strazhar",
  "hook": "enemy_tactics.gd · champion entre en jeu",
  "desc": "Cor de Byrsa ré–la puis galop de la ruée.",
  "db": -8,
  "dur": 1.6
 },
 {
  "id": "martyre",
  "cat": "Credo et Byrsa",
  "elem": "Apparition de la Martyre",
  "hook": "martyre.gd · entrée en combat singulier",
  "desc": "Deux coups de cloche d'or sur une quinte à vide.",
  "db": -8,
  "dur": 2.6
 },
 {
  "id": "croc",
  "cat": "Faune",
  "elem": "Crocodile qui happe",
  "hook": "wildlife.gd · croc",
  "desc": "Claquement de mâchoire et éclaboussure.",
  "db": -13,
  "dur": 0.4
 },
 {
  "id": "felin",
  "cat": "Faune",
  "elem": "Félin qui feule",
  "hook": "wildlife.gd · feline (aggro)",
  "desc": "Feulement soufflé sur un grondement grave modéré.",
  "db": -14,
  "dur": 0.55
 },
 {
  "id": "portail",
  "cat": "Monde et ouverture",
  "elem": "Portail d'argent (arrivée J1)",
  "hook": "opening.gd · ARR_OPEN",
  "desc": "Nappe de trois sinus qui ondulent et scintillent.",
  "db": -10,
  "dur": 1.8
 },
 {
  "id": "expulsion",
  "cat": "Monde et ouverture",
  "elem": "L'Ingénieur expulsé, tombe à genoux",
  "hook": "opening.gd · ARR_EJECT",
  "desc": "Chute en glissando puis impact au sol.",
  "db": -10,
  "dur": 0.9
 },
 {
  "id": "porte_barree",
  "cat": "Monde et ouverture",
  "elem": "Porte sud barrée",
  "hook": "opening.gd · DOOR_LINE",
  "desc": "Trois coups sourds contre le bois, verrou qui cliquette.",
  "db": -10,
  "dur": 0.5
 },
 {
  "id": "ancre_trait",
  "cat": "Monde et ouverture",
  "elem": "Réveil de l'Ancre : le trait court vers la capsule",
  "hook": "opening.gd · « link » (LINK_LEN 2,2 s)",
  "desc": "Bourdonnement qui monte d'une octave sur la durée exacte du trait.",
  "db": -12,
  "dur": 2.2
 },
 {
  "id": "capsule",
  "cat": "Monde et ouverture",
  "elem": "La capsule s'allume",
  "hook": "opening.gd · « awake »",
  "desc": "Déclic, ronronnement la–mi, une note de confirmation.",
  "db": -11,
  "dur": 1.2
 },
 {
  "id": "bouclier_forme",
  "cat": "Monde et ouverture",
  "elem": "Formation du bouclier d'énergie",
  "hook": "opening.gd · « shield_form » (ANCHOR_SEQUENCE)",
  "desc": "Double glissando montant puis tenue cristalline. Pour la suite mise de côté.",
  "db": -11,
  "dur": 2.0
 },
 {
  "id": "canon",
  "cat": "Monde et ouverture",
  "elem": "Canon de Byrsa et impact sur le bouclier",
  "hook": "opening.gd · « siege » (ANCHOR_SEQUENCE)",
  "desc": "Détonation, sifflement, puis onde de verre à l'impact.",
  "db": -10,
  "dur": 1.1
 },
 {
  "id": "onde",
  "cat": "Monde et ouverture",
  "elem": "Explosion : onde rose qui souffle le mur",
  "hook": "opening.gd · « blast » (ANCHOR_SEQUENCE)",
  "desc": "Montée tremblée puis souffle long. Seul son vraiment ample de la liste.",
  "db": -7,
  "dur": 2.6
 },
 {
  "id": "vague",
  "cat": "Monde et ouverture",
  "elem": "Début d'un assaut",
  "hook": "simulation.gd · lancement de vague",
  "desc": "Cor la–la–mi et deux coups de tambour.",
  "db": -9,
  "dur": 2.0
 },
 {
  "id": "aube",
  "cat": "Monde et ouverture",
  "elem": "Lever du jour",
  "hook": "jour/nuit · aube",
  "desc": "Accord suspendu qui s'ouvre, très lent.",
  "db": -14,
  "dur": 1.8
 },
 {
  "id": "crepuscule",
  "cat": "Monde et ouverture",
  "elem": "Tombée de la nuit (félins plus agressifs)",
  "hook": "jour/nuit · crépuscule",
  "desc": "Descente mi–do–la, quelques insectes.",
  "db": -14,
  "dur": 2.0
 },
 {
  "id": "quete",
  "cat": "Monde et ouverture",
  "elem": "Quête accomplie",
  "hook": "sim/quests.gd · condition remplie",
  "desc": "La–mi–la : retour à la tonique. Plus bref que « victoire ».",
  "db": -10,
  "dur": 1.1
 },
 {
  "id": "defaite",
  "cat": "Monde et ouverture",
  "elem": "Défaite (Ancre détruite)",
  "hook": "Events.game_over(false)",
  "desc": "Mi–ré–do vers un la mineur tenu. Grave modéré, pas de glas.",
  "db": -6,
  "dur": 3.0
 },
 {
  "id": "arbalestrie",
  "cat": "Exilés",
  "elem": "Tir de l'Arbalestrie (Ingénieur)",
  "hook": "combat.gd · gear_attack, arme à mana",
  "desc": "Déclic, corde sèche, petit scintillement d'énergie. 0,2 s : fini avant le tir suivant (cadence 0,25 s).",
  "db": -15,
  "dur": 0.2
 }
];
