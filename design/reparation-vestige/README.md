# Réparation gratuite du Vestige envahi par l’ingénieur

[Ouvrir la proposition animée](../../reparation-vestige.html).

## Règles retenues

- Acteur : **ingénieur**, aucune intervention du prêtre dans cette séquence.
- Coût : **0 ressource**, sans paiement ni prélèvement à l’arrivée, pendant le travail ou à la fin.
- Départ : Vestige envahi, ruine 04 retenue.
- Arrivée : Garde tyrienne fonctionnelle, chargement par une ouverture dans le socle et direction de tir **NE**.
- La tourelle ne charge ni ne tire avant la fin de sa remise en état.

## Séquence proposée

| Temps | Action de l’ingénieur | Mouvement de la tourelle |
| --- | --- | --- |
| 0–1 s | Approche et préparation des outils | Ruine inchangée |
| 1–2,6 s | Retrait des végétaux et gravats | La trappe du socle se dégage |
| 2,6–5,1 s | Action du treuil et du câble de chantier | Le rail se relève ; les montants se redressent |
| 5,1–7 s | Remontage et fixation des bras, contrôle du mécanisme | Les bras reprennent leur position ; la corde revient en place |
| 7–8 s | Dernières fixations et remise en service | Finition des ferrures, bannière restaurée, sceau actif |
| 8–12 s | L’ingénieur s’écarte | Chargement par le bas et tir d’essai vers NE |

La durée de réparation de 8 secondes est une proposition ; la gratuité est une règle demandée par l’utilisateur. Le tir a lieu environ 2,736 secondes après la fin de réparation, conformément au cycle automatique existant.

Le déblaiement réduit progressivement la présence de mousse et débris. La charpente et les bras changent réellement de position. Une courte transition de finition à la fin raccorde ces éléments à l’asset fonctionnel existant ; l’ensemble de la réparation n’est pas un simple fondu entre deux images. L’ingénieur illustré utilise la palette cuir/bleu/laiton et un crochet de siège ; c’est une silhouette d’animation de proposition, pas une nouvelle sélection définitive d’unité.

## Livrables

- `../../reparation-vestige.html` : animation, progression, coût nul permanent, pause, ralenti, curseur temporel et relance gratuite ; s’arrête à la fin de la démonstration.
- `reparation-NE.gif` : aperçu partageable d’environ 12 s, réparation suivie de l’essai. Le GIF rejoue en boucle pour la consultation.
- `storyboard.png` : six étapes du mouvement.
- `sequence.json` : durée, acteur, coût et étapes.
- `reparation-vestige.zip` : aperçu animé, storyboard, séquence et documentation.
- `../../assets/ballista-repair.js` : scène Canvas indépendante du jeu ; s’appuie sur `ballista-ruins.js` et `ballista.js`.
- `render-commands.json.gz`, `export-animation.py` : commandes du rendu et exporteur Pillow reproductible.

## Vérification et portée

Les 289 positions de prévisualisation ont été parcourues sans coordonnées non finies. Gratuité et acteur ingénieur vérifiés sur toutes les positions ; état fonctionnel impossible avant 8 s et actif ensuite. La syntaxe du script de page est vérifiée. Storyboard et images clés inspectés visuellement. La proposition ne modifie pas l’économie ni les unités du jeu principal : l’intégration reste à réaliser après validation du mouvement.
