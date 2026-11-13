# Ballistes tyriennes — cinq propositions

**Suite retenue : [Garde tyrienne avec chargement par le socle et huit orientations](../garde-tyrienne/README.md).** Les cinq propositions ci-dessous sont conservées comme historique.

Ouvrir [la planche animée](../../balistes-propositions.html) dans un navigateur. Elle fonctionne sans serveur ni dépendance externe. Les cinq propositions sont des alternatives : une partie utilise deux exemplaires du modèle retenu.

## Intention

Conserver le langage de la référence fournie : baliste en chêne, renforts de fer, ferrures de laiton, bannière bleue et embase de pierre. Le prêtre réactive successivement les deux sceaux au début du jeu. Après cette réactivation, l’alimentation en traits, la tension et les tirs sont entièrement automatiques. L’équipe humaine figurant sur la référence n’est donc pas reprise.

| Proposition | Alimentation et tension | Silhouette | Cycle de prévisualisation |
| --- | --- | --- | --- |
| 01 · Garde tyrienne | Magasin vertical, double treuil | Baliste classique, large arc | 3,6 s |
| 02 · Sentinelle à barillet | Barillet indexé à six logements | Tambour latéral bien visible | 3,3 s |
| 03 · Jumelle du rempart | Deux rails et treuils indépendants | Large, deux têtes alternées | 4,4 s par rail |
| 04 · Aiguille du sanctum | Élévateur, contrepoids de tension | Haute, long rail de précision | 4,6 s |
| 05 · Égide à chaîne | Convoyeur à chaîne, poussoir | Basse, joues blindées | 3,8 s |

**Recommandation : Garde tyrienne.** Elle conserve le mieux l’identité de l’image et communique immédiatement son rôle de première défense. La Sentinelle est une bonne alternative si l’on veut mettre l’accent sur l’automatisation.

## Livrables

- `../../balistes-propositions.html` : comparaison interactive, modèle de base, rechargement et tir pour chaque variante ; scène des deux tourelles avec réactivation par le prêtre ; pause, vitesse et curseur temporel.
- `../../assets/ballista.js` : cinq modèles 2D procéduraux, géométrie commune articulée et rendu Canvas indépendant du jeu principal.
- `modele-01.png` à `modele-05.png` : cinq vues agrandies des modèles procéduraux.
- `01-garde-tyrienne.gif` à `05-egide-a-chaine.gif` : cinq cycles complets animés, exportés à environ 30 images/seconde.
- `prompts.json` : demandes de génération des cinq planches détaillées (aucune image générée : outil imagegen refusé par son filtre « violence »).

Les PNG sont des rendus fixes des modèles 2D procéduraux. Les animations effectives se trouvent dans les prototypes Canvas de la page HTML et les GIF ; il ne s’agit pas d’animations de modèles 3D ni de fichiers GLB riggés. La génération de planches détaillées avec l’outil intégré imagegen a été tentée, puis refusée par le filtre de sécurité « violence » ; aucun rendu IA n’est livré. Les GIF et PNG ont été rasterisés depuis la géométrie Canvas avec Pillow.

## Cycle animé

Un cycle commence avec le rail vide. Alimentation de 5 à 25 % ; treuil et tension de 22 à 66 % ; verrouillage jusqu’à 76 % ; lâcher entre 76 et 79,5 % ; départ du projectile jusqu’à 94 % ; retour amorti avant la fin du cycle. La corde et les bras suivent la tension, le chariot absorbe le recul. Les rails de la Jumelle sont déphasés d’un demi-cycle. Les deux tourelles de la scène sont elles aussi déphasées.

Les boucles de rechargement et de tir sont isolées pour examen ; leur remise au début est intentionnelle. La scène montre l’enchaînement complet. La réactivation de démonstration se rejoue toutes les quinze secondes pour permettre sa comparaison, mais l’intention en jeu est une réactivation unique au début de partie.

## Périmètre

Les cadences et rôles sont des intentions à équilibrer, pas des statistiques de gameplay validées. Les réserves de munitions de la prévisualisation ne s’épuisent pas. Aucun changement apporté au jeu principal, au Sanctum existant ni aux autres pages de propositions. L’intégration définitive dépend du modèle retenu.

## Vérification

Syntaxe des deux scripts vérifiée. Les cinq modèles ont été exercés en base, rechargement, tir et cycle complet à plusieurs temps, ainsi que la scène de réactivation ; coordonnées numériques finies. Initialisation de la page et commandes pause/reprise/réactivation exercées dans un DOM simulé. Les silhouettes ont fait l’objet d’un rendu de contrôle hors navigateur. Une vérification visuelle dans le navigateur cible reste souhaitable avant intégration au jeu.
