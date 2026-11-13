# Temples de Sigil — planche animée

Ouvrir `../../temple-propositions.html` dans un navigateur. Aucun serveur ni dépendance nécessaires.

Cinq propositions Canvas natives, avec un prêtre commun : Sceau astral, Sanctuaire des flèches, Source des esprits, Cloître de Sigil et Astre ascendant. Inspiration visuelle : référence fournie par l’utilisateur (pierre blanche, or, étoffes sombres, géométrie sacrée, lumière bleue). Dessins procéduraux, sans ImageGen.

Le moteur réutilisable est `../../assets/temple.js` : `TempleKit.DESIGNS`, `TempleKit.render(context, design, seconds)` et `TempleKit.priest(context, x, y, seconds, mode, scale)`. Canevas temple 320 × 240 ; modes du prêtre : `walk`, `pray`.

Cycle illustratif de 20 secondes : construction 0–2 s, apparition en bas à droite dès 2 s, marche 2–5 s, prière jusqu’à la fin. Gains de 10 Esprit à 8, 12 et 16 s ; compteur réinitialisé au prochain cycle. Le +10 apparaît en 0,3 s, reste une seconde, disparaît en 0,5 s et monte de 12 pixels. La cadence et la durée de construction sont des paramètres de démonstration, pas des règles d’équilibrage.

Animation par requestAnimationFrame, temps indépendant du nombre d’images. Pause, vitesse 0,25× à 2×, relance et respect initial de prefers-reduced-motion. Aucun changement dans Index.html ou dans l’économie de la partie : propositions à choisir avant intégration.

Validation : moteur exécuté pour les cinq designs à treize instants couvrant les transitions ; aucun échec. Le rendu visuel automatisé n’a pas pu être vérifié dans cet environnement (Chromium système bloqué et chargement de Playwright indisponible).

## Direction 1 — construction par Énonciation

La page principale présente désormais cinq constructions du même Sceau astral. Moteur : `assets/temple-construction.js`, exposant `TempleConstructionKit.DESIGNS` et `render(context, design, seconds)`.

Chaque fragment provient du dessin final : il sort d’un point du sol, suit une trajectoire propre à la variante et s’assemble à sa position définitive. Fissures, poussière, gestes et ondes dorées de l’Artisan Exilé accompagnent l’extraction. Les cinq propositions : assises de la Parole, spirale d’Énonciation, mains invisibles, litanie des piliers, plan suspendu.

Nouveau cycle : construction 0–8 s ; apparition du prêtre à 8 s ; marche jusqu’à 11 s ; gains +10 à 14, 18 et 22 s ; relance à 26 s. Curseur temporel pour comparer les étapes en pause. Le compteur est illustratif et se réinitialise à chaque cycle. Les cinq architectures initiales restent disponibles dans TempleKit.DESIGNS.

Vérification : 85 rendus simulés couvrant les cinq variantes et les transitions de production, coordonnées numériques et compteurs contrôlés, script de page syntaxiquement valide. Contrôle visuel via navigateur intégré bloqué par sa politique d’accès aux URL file://.

## Intégration au jeu — piste 1 retenue

Dans `Index.html`, sélectionner l’Ingénieur après sa sortie du portail puis utiliser **Temple · gratuit** ou **B**. Cliquer dans un espace libre de la clairière ; aperçu vert si valide, rouge sinon. Échap ou clic droit annule le mode de placement. Aucun coût de construction et aucune limite de nombre ajoutés.

L’Ingénieur rejoint le bord du chantier avant de commencer les huit secondes d’Énonciation. La construction utilise les assises de la Parole ; les fragments et les ondes sont guidés depuis le véritable Ingénieur, sans second personnage illustratif. Un nouvel ordre de déplacement ou de position, ou la mort de l’Ingénieur, annule son chantier inachevé. Les temples terminés continuent de fonctionner indépendamment de lui.

À l’achèvement, le prêtre apparaît en bas à droite du temple, marche trois secondes puis prie. Production de **10 Esprit toutes les quatre secondes de prière**, avec un +10 interpolé (0,3 s de fondu, 1 s de maintien, 0,5 s de disparition). Le total est affiché dans le HUD et les temples sont indiqués sur la mini-carte. Rejouer efface les temples et réinitialise l’Esprit.

Vérification d’intégration en simulation : approche réelle et achèvement, emplacement occupé et chevauchement refusés, absence de production prématurée et de double crédit, production répétée, plusieurs temples gratuits, interruption par déplacement/position/mort, réinitialisation. Le contrôle visuel dans le navigateur reste indisponible dans cet environnement.

## Retour visuel d’Esprit — fluidité et progression

Le gain et son icône sont désormais dessinés à la résolution d’affichage, séparément du sprite agrandi sans lissage. Dans la planche, un canvas superposé suit la taille du panneau et la densité de pixels de l’écran ; dans le jeu, le dessin utilise directement le contexte principal. Les positions restent fractionnaires et les fondus/montées utilisent une interpolation continue.

Le canal bleu de l’anneau astral se remplit dans le sens horaire pendant quatre secondes, à partir du début de la prière. Un éclair circulaire marque chaque gain. L’icône devant +10 reprend le motif astral de la ressource Esprit du HUD. `TempleKit.feedback` est partagé entre jeu et planche.

La planche est alignée sur la cadence du jeu : construction jusqu’à 8 s, marche jusqu’à 11 s, puis gains à 15, 19 et 23 s. Dans le jeu, le temps d’apparition du gain est ancré sur l’échéance de production, plutôt que sur l’image qui constate le gain.

Validation : syntaxe des scripts et pages, progression à 0/50/100 %, crédits aux échéances, absence de double décalage entre gain et effet, plus de 100 positions distinctes sous le pixel pendant une montée à 60 images/s. Contrôle visuel en navigateur non effectué.

## Emprise avant construction

L’aperçu de placement est un cercle avec une étoile à sept branches tournant en son centre, posé dans le plan du sol. Vert si constructible, rouge sinon. Ce même tracé reste visible sur le chantier en attente de l’Ingénieur, avec une rotation pilotée par le temps du jeu même lorsque la progression de construction est à zéro. La planche utilise aussi ce motif avant et pendant l’assemblage. Dans le jeu, le tracé est dessiné à la résolution d’affichage pour conserver une rotation fluide.

## Arrivée du prêtre depuis la jungle

Le prêtre du jeu est désormais un personnage dans le monde, dessiné indépendamment du temple et trié avec les arbres et unités selon sa profondeur. À l’achèvement, il part de la jungle au sud (z = 60), rejoint l’escalier à vitesse constante de 3,8 unités/s et commence à prier à son arrivée. Le remplissage de l’anneau et la production ne commencent qu’à cette arrivée ; le premier +10 suit quatre secondes plus tard. La mini-carte indique également sa progression.

Dans la planche, des feuillages au premier plan montrent sa sortie depuis le bas de la scène. Le trajet illustratif dure cinq secondes : départ à 8 s, arrivée à 13 s, gains à 17, 21 et 25 s, boucle de 28 s.

Vérification : syntaxe des scripts et des pages, départ dans la jungle, position intermédiaire, arrivée et premier gain après quatre secondes de prière pour trois emplacements de temple.
