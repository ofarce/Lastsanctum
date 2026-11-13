# Scieries de Medeina — deuxième direction artistique

Ouvrir `../../scierie-propositions.html` et recharger la page si elle était déjà ouverte.

Cinq silhouettes peintes : Atelier des ramures, Roue des sources, Grand Arbre, Halle des forestiers, Treuil sylvestre. Atlas original généré avec ImageGen : `medeina-atlas-v2.png`, grille 3 × 2, cinq bâtiments et un artisan. L’ancienne version Canvas reste disponible dans `assets/sawmill.js` pour les primitives et les icônes ; `assets/sawmill-v2.js` remplace le rendu des modèles.

Rendu Canvas à triple résolution. Extraction du fond connecté aux bords au chargement. Articulation des jambes et du buste du modèle peint ; mouvement de levier. Animation des disques en perspective, roue hydraulique, roues de transmission, charge du treuil, lumière et sciure. Ce sont des études 2D articulées, pas des modèles 3D ni des cycles de personnages dessinés image par image.

Cycle : construction 0–8 s ; apparition à la lisière en bas à droite à 8 s ; marche jusqu’à 13 s ; production +10 Bois à 17, 21 et 25 s. Au-dessus du temple témoin : icône bois, montée de 16 pixels et fondu 0,3 s, maintien 1 s, disparition 0,5 s. Pause, vitesse et curseur conservés. Planche indépendante du jeu.

Validation : syntaxe des scripts et 75 états simulés après chargement de l’atlas, transitions et montants des gains. Illustration source inspectée. Contrôle du rendu final dans le navigateur bloqué par la politique d’accès aux URL file://.

## Modèle retenu : 03 · Le Grand Arbre

La page présente désormais uniquement le modèle choisi. `assets/sawmill-grand-arbre.js` remplace le modèle peint par un rendu natif avec les mêmes primitives Px, les palettes C.bark / C.leaf / C.moss et les fonctions de texture du jeu (decor.js). Aucun asset raster généré n’est utilisé pour ce bâtiment.

Construction : émergence du tronc et de la canopée 0,35–3,6 s, puis déploiement des racines/plancher, poteaux, toiture végétale, établi, grue et finitions depuis le tronc, jusqu’à 8 s. Les couches restent distinctes pour éviter un simple dévoilement vertical de l’image. Artisan natif, arrivée et gains conservés. Validation : 280 instants simulés couvrant un cycle complet ; montants de bois et syntaxe de la page vérifiés. Le rendu final n’a pas été contrôlé visuellement dans un navigateur.
