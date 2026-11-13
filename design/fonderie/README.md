# Puits de fonderie — Forgerons d’Aether

Ouvrir `../../fonderie-propositions.html` : cinq propositions animées en Canvas, adaptées au style natif du jeu et aux matériaux de la référence (pierre sombre, laiton, acier, étoile, énergie bleue).

1. Puits astral : astrolabe et grue à minerai.
2. Halle des creusets : trois fours, soufflets et convoyeur.
3. Tour d’Aether : condensateur vertical et anneaux.
4. Forges jumelles : cheminées et presse mécanique.
5. Grand Balancier : portique, transmission et levage.

Modèle commun du forgeron : capuche ivoire, manteau bleu, tablier et étoile de laiton. Études animées de marche, transport de lingot et commande du levier. Construction 0–8 s ; apparition à la forêt en bas à droite à 8 s ; arrivée à la machine à 13 s. Production illustrative : +10 Fer à 17, 21 et 25 s. Cycle de démonstration de 28 s, avec pause, reprise, curseur temporel et vitesse réglable. Mouvement réduit respecté à l’ouverture.

Chaque crédit déclenche une icône de lingot et +10 au-dessus du temple témoin : fondu d’entrée 0,3 s et montée de 16 pixels, maintien 1 s, fondu de sortie 0,5 s. Le moteur `../../assets/foundry.js` expose FoundryKit.DESIGNS, building, worker, render, feedback et ironIcon. Réutilise TempleKit et UnitKit pour le chantier. La planche ne modifie pas la partie principale ; rendement et cadence restent illustratifs.

Validation : syntaxe JavaScript du moteur et de la page, 85 rendus simulés couvrant cinq modèles et les transitions, crédits vérifiés autour des échéances, trois poses exécutées. Pas de contrôle visuel dans un navigateur pendant cette passe.

Révision 2 : nouvelles architectures à volumes isométriques, maçonnerie, arches de fours, bannières, astrolabe, anneaux, presse et grue. Rendu haute résolution, planche sur deux colonnes. Forgeron redessiné avec tablier et gants ; départ visible dans la forêt à droite. Démarrage à 14 s pour présenter les bâtiments achevés ; rejouer lance la construction. Contrôle visuel effectué en navigateur, crédit à 17,5 s confirmé pour les cinq propositions. Aperçu : `apercu-v2.png`.

## Modèle retenu : 02 — Halle des creusets

Intégré dans `../../Index.html` avec `../../assets/foundry-game.js`. Sélectionner l’Ingénieur, puis F ou « Fonderie · gratuit », puis cliquer un emplacement libre. Construction gratuite de 8 secondes après le trajet du bâtisseur, comme le temple. Le forgeron apparaît dans la forêt en bas à droite (coordonnées monde 55,42), rejoint la fonderie à 3,8 unités/s, puis produit 10 Fer toutes les 4 secondes. Le compteur et les gains suivent le temps de simulation, sans remise à zéro périodique. Le gain apparaît au-dessus du temple achevé le plus proche, sinon de l’Ancre. Déplacement, maintien de position, nouveau chantier et mort interrompent un chantier inachevé. Relancer la partie remet le Fer à zéro.

Tests : `tests/foundry-game.test.mjs` et `tests/turret-game.test.mjs` passent. Contrôle visuel du jeu intégré non achevé : chargement du jeu sans réponse dans le navigateur de contrôle. La planche autonome a été contrôlée visuellement précédemment.
