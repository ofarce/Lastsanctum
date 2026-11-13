# Garde tyrienne — chargement par le socle

[Ouvrir les huit orientations animées](../../baliste-garde-tyrienne.html).

Modèle 01 retenu. Les pieux viennent d’une réserve sous le socle : deux volets coulissent, un berceau monte un pieu horizontal jusqu’au rail, puis redescend avant la fermeture. Le treuil tend automatiquement la corde ; l’arme tire et son chariot absorbe le recul. Aucun magasin au-dessus du rail. Les deux tourelles de la scène du sanctum sont orientées **nord-est**.

## Orientations et sprites

N en haut de l’écran, E à droite ; NE vise le coin supérieur droit. Huit vues : N, NE, E, SE, S, SO, O, NO. Elles proviennent d’une rotation de la géométrie avant projection, pas d’une rotation ou d’un simple miroir du sprite. Les surfaces latérales visibles sont recalculées pour chaque cap.

- `orientations.png` : planche lisible avec les huit directions.
- `orientations-transparent.png` : atlas de repos, quatre colonnes et deux rangées ; ordre N, NE, E, SE, S, SO, O, NO.
- `idle-{direction}.png` : arme chargée ; `inactive-{direction}.png` : état inactif avant réactivation.
- `atlas-{direction}.png` : 96 images d’un cycle automatique complet, douze colonnes et huit rangées.
- `sprites.json` : rectangles des images, pivot, durées, événements, séquences et vecteurs de tir.
- `cycle-NE.gif` : aperçu du rechargement et du tir au nord-est. Le projectile doit être créé séparément en jeu.

Chaque case mesure **192 × 192 pixels**, avec transparence réelle. Le pivot commun est **(96, 155)** au pied du socle ; ce repère ne bouge pas entre les orientations ou les images du cycle. L’ombre semi-transparente est incluse.

## Cycle et intégration

Le cycle dure 3,6 s, à raison de 37,5 ms par image (environ 27 images/s). L’image 73 déclenche l’événement de tir ; le JSON contient la direction écran normalisée. Pour NE : x = +0,7071 et y = −0,7071. Le projectile est **exclu des atlas** pour qu’il puisse continuer sa trajectoire sans être découpé par les limites du sprite. Les vues Canvas de la page affichent ce projectile pour la prévisualisation.

Le JSON fournit une séquence `reload` d’images 0 à 72 et une séquence `fire` d’images 73 à 95, ainsi qu’un cycle complet en boucle. Les PNG `idle` servent à l’attente, arme chargée. Il n’y a pas de réserve limitée dans la prévisualisation. Les deux tourelles du sanctum sont déphasées d’un demi-cycle après la réactivation par le prêtre.

La page affiche le rendu vectoriel animé en continu, sans imposer la cadence des atlas. Pause, vitesse réduite et sélection des orientations permettent d’inspecter le mouvement.

## Reproduction

`capture-sprites.mjs` expose la fonction asynchrone `captureSprites(root)`, à appeler sous Node.js avec le chemin absolu de `Lastsanctum`. Elle lit `assets/ballista.js` et écrit `render-commands.json.gz`. Exécuter ensuite `python3 export-sprites.py` avec Pillow installé. Ce dernier rasterise les commandes Canvas, exporte les atlas, les vues et le GIF, et vérifie que les sprites sont contenus dans leurs cases.

Les PNG sont des sprites 2D procéduraux ; aucun appel à ImageGen pour cette déclinaison. Le jeu principal n’est pas modifié.

## Validation

Syntaxe JavaScript vérifiée ; huit directions et quatre modes parcourus à cent positions du cycle, sans coordonnées non finies. Le cap projeté NE a x positif, y négatif et une pente de −1. Les limites de chaque sprite et la transparence sont vérifiées à l’export. Planche des huit vues et images clés de rechargement contrôlées visuellement hors navigateur.
