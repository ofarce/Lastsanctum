# Garde tyrienne — ruine retenue : Vestige envahi

[Proposition animée de réparation gratuite par l’ingénieur](../../reparation-vestige.html).

**Choix utilisateur : proposition 04, Vestige envahi, pour les deux tourelles initiales.** Après restauration, elles retrouvent la Garde tyrienne à chargement par le socle et tirent vers NE. `vestige-envahi-retenu.zip` contient uniquement les huit sprites retenus, leur atlas et les métadonnées.

[Ouvrir la comparaison des quatre ruines](../../tourelles-ruines-propositions.html).

La Garde tyrienne et son chargement par le socle sont conservés comme modèle de référence. Les variantes sont des alternatives artistiques pour les deux tourelles présentes au début de partie, pas une progression obligatoire de destruction.

1. **Sentinelle abandonnée** : structure intacte, corde détendue, treuil grippé, trappe obstruée ; convient à une remise en service rapide.
2. **Arc rompu** : un bras manquant et détaché, corde rompue, plateforme et élévateur conservés ; dommage identifiable à petite échelle, avant/après lisible.
3. **Charpente affaissée** : rail incliné, support cassé, treuil détaché au sol ; remise en état structurelle plus importante.
4. **Vestige envahi — retenue** : structure basse, bras brisés, éboulis, mousse et lierre ; donne une impression d’abandon ancien et de reconstruction plus longue.

Dans chaque version : sceau éteint, bannière effilochée, aucune munition chargée, aucune animation de fonctionnement. Le socle octogonal et l’ouverture d’alimentation restent identifiables. Le rail conserve son orientation future de tir. Les dégâts sont dessinés dans la géométrie ; ce ne sont pas des versions simplement assombries du modèle actif.

## Sprites

- 32 PNG transparents, nommés `{proposition}-{direction}.png` : quatre propositions × huit directions.
- Chaque sprite mesure 192 × 192, avec pivot (96, 155), identique au modèle réparé.
- Huit caps écran : N, NE, E, SE, S, SO, O, NO. NE est le cap principal.
- Quatre fichiers `{proposition}-orientations.png` : atlas de quatre colonnes et deux rangées, dans le même ordre.
- `propositions-ruines-NE.png` : planche comparative avec les quatre propositions orientées NE.
- `sprites.json` : descriptions, réparations envisagées, noms de fichiers, rectangles d’atlas et pivot.
- `tourelles-ruines-sprites.zip` : tous les PNG, le JSON et cette documentation.

La page compare chaque ruine au modèle réparé avec exactement la même échelle, le même pivot et la même direction. L’aperçu réduit est affiché à 96 × 96 pour vérifier sa lecture dans le jeu.

## Sources et vérification

`../../assets/ballista-ruins.js` fournit le rendu Canvas procédural et les quatre designs ; il réutilise uniquement la table d’orientations de `ballista.js`. `render-commands.json` enregistre la géométrie des 32 sprites ; `export-ruins.py` utilise le rasteriseur Pillow du dossier `garde-tyrienne` pour les exporter.

Les 32 sprites ont été contrôlés pour les dimensions, la transparence et l’absence de débordement. Les coordonnées des huit orientations ont été vérifiées ; les rendus NE font l’objet d’un contrôle visuel. La page HTML est vérifiée pour sa syntaxe et son changement d’orientation dans un DOM simulé. Aucune intégration au jeu principal ni animation de réparation dans cette proposition.
