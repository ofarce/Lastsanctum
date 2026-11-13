# Tourelles du sanctum — intégration au jeu

Le jeu `Index.html` contient deux Vestiges envahis, en (−23, 11) et (+23, 11), sur les deux flancs du sanctum. Un clic droit sur une tourelle en ruines assigne l’ingénieur sélectionné, ou le plus proche ingénieur vivant et sorti du portail. Le glisser droit continue de déplacer la caméra sans donner d’ordre.

L’ingénieur marche au point de travail. La réparation prend 8 secondes de présence effective, sans dépense de ressource, puis la Garde tyrienne devient autonome. L’animation reprend le déblaiement, le relevage de la charpente, le remontage des bras et la finition. Le véritable ingénieur du jeu reste visible, avec outil et câble de travail ; aucune deuxième unité fictive n’est ajoutée.

Un ordre de déplacement, maintien de position ou construction de temple interrompt le chantier, avec conservation de l’avancement. La mort de l’ingénieur libère aussi le chantier ; un autre ingénieur peut le reprendre. Le redémarrage restaure les deux ruines et efface les projectiles et affectations.

Statistiques initiales : portée 140 unités de monde, dégâts 80 par pieu, cycle nominal 3,6 s. Les créatures (35 PV) et cracheurs (48 PV) meurent en un coup ; les brutes (110 PV) nécessitent deux coups. Les dégâts sont appliqués à l’impact, après déplacement visible du projectile. Les tourelles évitent de tirer toutes deux sur un ennemi déjà condamné par un pieu en vol.

Les sprites démarrent au nord-est et s’orientent sur huit directions en suivant leurs cibles. Les deux tourelles sont incorporées au tri de profondeur, et figurent sur la minicarte. Le HUD indique la réparation gratuite de l’ingénieur. La zone des socles est réservée pour éviter la superposition avec un temple construit.

Validation : `tests/turret-game.test.mjs` utilise les vrais scripts de gameplay et la vraie boucle `update`, avec un Canvas et un DOM simulés. Il vérifie clic droit, trajet, gratuité, durée, interruptions, décès, recommencement, portée, dégâts à l’impact, coordination des tirs et chemins de rendu. Exécuter sous Node.js : `node tests/turret-game.test.mjs` depuis le dossier Lastsanctum. Les fonctions de simulation et de rendu sont exercées ; cette vérification ne remplace pas une inspection visuelle en navigateur.

Validation navigateur complémentaire : `python3 tests/turret_browser_smoke.py` lance Chromium et vérifie la progression du temps, la présence des deux tourelles dans la vraie boucle de rendu GPU, le clic droit, le raccord de fin de réparation et les dégâts du projectile, sans exception JavaScript. Les tourelles et leurs projectiles sont capturés dans le calque GPU après leur dessin Canvas pour rester visibles.

Compatibilité des navigateurs intégrés : Canvas 2D est désormais le rendu par défaut ; WebGL reste opt-in avec `?renderer=webgl`. Le module 3D du Tireur ne charge Three.js et ne crée son contexte que lors du passage explicite en mode 3D (P). La boucle programme son image suivante avant le dessin et repasse en Canvas si le décor WebGL déclenche une erreur. `Jouer.html` ouvre une URL de jeu versionnée pour éviter de seulement refocaliser un ancien onglet déjà figé. Le test `python3 tests/turret_browser_smoke.py --disable-webgl` couvre huit secondes complètes de réparation gratuite, l’impact d’un projectile et le recommencement sans WebGL.
