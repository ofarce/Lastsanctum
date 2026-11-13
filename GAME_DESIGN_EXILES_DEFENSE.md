# EXILESDEFENSE — Document de concept et de conception du jeu

**Projet** : *Exilés — Sanctum Lacertae*  
**Version documentaire** : 0.1 — 13 novembre 2026  
**Référence narrative** : `LORE_TERRES_FEROCES_REFONDUES.md`  
**Cible initiale** : jeu solo directement lançable dans un navigateur de bureau.

## 1. Vision du jeu

**Pitch** : une cellule de trois **Exilés**, aidée de trois escouades de **disciples d'Indra**, défend une installation tyrienne cachée dans la jungle contre des assauts de créatures corrompues. Le joueur contrôle et positionne ses défenseurs en temps réel pour empêcher les ennemis d'atteindre la sphère noire suspendue dans le Sanctum : **l'Ancre**.

**Genre** : tactique en temps réel / défense d'objectif, caméra isométrique.  
**Format** : petite expérience autonome de **10 à 15 minutes** visant à éprouver le combat, les rôles, la lisibilité de l'interface et la direction artistique.  
**Approche** : développer le gameplay d'abord ; enrichir progressivement le lore en répondant aux questions posées par la mécanique.

### Objectifs de cette première expérience

- Une boucle de combat amusante sur une carte unique.
- Trois Exilés réellement complémentaires.
- Trois escouades capables de couvrir les deux accès au temple.
- Des ennemis faibles mais suffisamment variés pour tester tir, mêlée et soins.
- Une identité propre au monde des Terres Féroces : architecture tyrienne, Ancre, traces d'Énonciation, disciples d'Indra.

### Hors périmètre de la première version

Monde ouvert, construction de base, économie, multijoueur, inventaire détaillé, crafting, campagne à plusieurs niveaux, personnalisation complexe, arbres de compétences, cinématiques ambitieuses.

## 2. Plateforme et technologie

### Version actuellement fournie

Le prototype jouable disponible dans la conversation est un **fichier HTML autonome** avec JavaScript et rendu **Canvas 2D projeté en isométrique** (aspect de volume « 2.5D »). **Il ne s'agit pas d'une scène 3D WebGL native ni d'un modèle GLB.** Il s'ouvre par double-clic, sans installation ni serveur, avec une caméra isométrique simulée.

Dernier fichier de référence délivré : **`EXILES_JOUER_TIREUR_V3_CORRIGE.html`**. Son code est susceptible d'être repris en `index.html` dans le dépôt `Exilesdefense`.

La version V2 du Tireur produisait un écran noir à cause d'une erreur JavaScript ; la V3 a été corrigée. Ne pas reprendre les fichiers V2.

### Évolution technique envisagée

- **Maintenir temporairement Canvas** si l'objectif est de prototyper très rapidement les comportements et les règles.
- **Migrer ensuite vers Three.js ou Godot 4 Web** pour une vraie scène 3D isométrique : meshes, éclairage, ombres, animations, navigation et import de modèles `.glb`.
- L'utilisateur souhaite un jeu **directement lançable dans le navigateur** : la distribution doit être simple, sans procédure technique obligatoire pour le joueur.
- Documenter explicitement l'éventuelle nécessité de servir les fichiers localement lors de la migration vers un moteur 3D : ne pas promettre un HTML autonome tant que toutes les ressources ne sont pas effectivement intégrées.

## 3. Carte : Sanctum Lacertae

### Layout

Le niveau représente une ancienne installation tyrienne au cœur d'une jungle.

1. **Jungle extérieure** : végétation dense, rochers, vestiges, zones d'apparition des créatures.
2. **Deux accès distincts** : deux chemins anciens venant de l'extérieur ; les ennemis peuvent être répartis entre ces routes.
3. **Clairière / esplanade** : zone dégagée avant le temple, espace d'affrontement et de placement des soldats.
4. **Temple de pierre** : structures monumentales vieillies, passages, pylônes et ruines.
5. **Chambre de l'Ancre** : salle contenant un autel et une **sphère noire flottante** au-dessus ; objectif à protéger.

### Contraintes de level design

- Les deux routes doivent être clairement distinguables depuis la vue isométrique.
- Le joueur doit toujours retrouver l'Ancre, même au milieu d'une mêlée.
- Les défenseurs doivent avoir des positions utiles : engagement frontal pour le Rempart, ligne de tir pour la Tireuse, position de soutien pour le Restaurateur.
- Les éléments verticaux ne doivent pas masquer indéfiniment les unités : transparence de toiture ou simplification de la géométrie au besoin.
- Les déplacements ne doivent pas traverser les murs lorsqu'une version avec navigation est implémentée.
- La forêt donne l'ambiance mais ne doit pas rendre les trajectoires impossibles à lire.

### Schéma simplifié

```text
                  JUNGLE / APPARITION
                 /                  \
          CHEMIN OUEST           CHEMIN EST
                 \                  /
                  \    CLAIRIÈRE   /
                   \              /
                [ ENTRÉE DU TEMPLE ]
                [   SALLE CENTRALE  ]
                [    ANCRE NOIRE    ]
```

## 4. Armée du joueur : 3 Exilés + 3 escouades d'Indra

### Exilé 1 — Rempart (interface : Paladin)

- **Armes** : épée et bouclier.
- **Fonction** : avant-garde, blocage de passage, encaissement des dégâts, corps à corps.
- **Combat** : dégâts de mêlée élevés, très bonne défense, faible capacité à traiter les ennemis lointains.
- **Compétence** : **Égide**, protection temporaire des alliés proches et éventuellement choc autour du Rempart.
- **Silhouette** : armure massive, bouclier lisible même à faible zoom, épée distinctive.

### Exilée 2 — Restaurateur (interface : Soigneur)

- **Armes** : équipement défensif léger et tir secondaire.
- **Fonction** : maintenir les défenseurs en vie, soutenir les escouades, restaurer des blessures.
- **Combat** : puissance moyenne au tir, faible en mêlée.
- **Compétence** : **Restauration de zone**, soin des alliés proches. Une réanimation devra être ajoutée plus tard avec des conditions clairement définies.
- **Silhouette** : appareil ou module médical reconnaissable, effets de soin lisibles sans saturer l'écran.

### Exilée 3 — Tireuse (interface actuelle : Tireur)

- **Arme** : **arbalète à répétition** à chargeur mécanique ; carreaux explosifs.
- **Fonction** : dégâts à distance, élimination des cibles prioritaires, soutien depuis une position arrière.
- **Combat** : excellente portée, cadence de tir soutenue, faible capacité de survie isolée en mêlée.
- **Compétence actuelle** : **Tir de précision** ; cible unique très endommagée.
- **Évolution proposée** : distinguer le tir normal de **carreaux explosifs** infligeant des dégâts de zone limités. La détonation doit être visible avec une petite onde, un éclair ambré et un impact au sol.
- **Silhouette de référence** : capuche ivoire, armure de plaques noir/acier argent, tabard et tissus cramoisis, épaulières, reliquaire dorsal, arbalète avec tambour, accessoires de munitions.
- **Important** : la planche de concept est une **image** ; la V3 du prototype possède un **dessin isométrique stylisé**, et non un véritable mesh 3D animé.

### Disciples d'Indra : trois escouades

- **3 escouades de 4 soldats** dans le prototype, soit **12 combattants** au départ.
- Chaque soldat est **polyvalent**, capable de tirer et de combattre au corps à corps.
- Les soldats alternent automatiquement entre attaque à distance et corps à corps en fonction de la proximité de la cible.
- Chaque escouade doit être sélectionnable en bloc et conserver une formation simple lors des déplacements.
- Compétence proposée : **Discipline martiale**, amélioration temporaire des performances d'une escouade.
- Identité : défenseurs disciplinés voués à Indra, distincts des Exilés technologiquement plus avancés.

### Première proposition d'équilibrage (indicative)

| Unité | Résistance | Attaque | Portée | Apport tactique |
|---|---|---|---|---|
| Rempart | Très élevée | Forte en mêlée | Très courte | Tient la ligne |
| Restaurateur | Moyenne | Faible | Moyenne | Répare les pertes |
| Tireuse | Moyenne / faible | Forte | Longue | Élimine les priorités |
| Disciple d'Indra | Standard | Modérée | Courte à moyenne | Couvre les accès |

Les valeurs numériques doivent être **testées en partie** ; celles du code actuel sont provisoires et ne constituent pas un contrat d'équilibrage.

## 5. Ennemis : premières unités faibles

En première version, viser trois archétypes simples :

1. **Corrompu / rampant** : faible résistance, déplacement rapide ou standard, attaque de mêlée. Sert à tester la ligne défensive.
2. **Brute corrompue** : plus lente, davantage de points de vie, frappe lourde. Sert à tester le Rempart et le focus de la Tireuse.
3. **Cracheur** : ennemi fragile doté d'une attaque à distance. Sert à tester le repositionnement et la protection du Restaurateur.

**Comportement minimal** : apparaître par une des deux routes, progresser vers les défenseurs ou l'Ancre, attaquer si une cible est à portée. Les vagues deviennent progressivement plus nombreuses. IA très simple acceptée pour un MVP ; navigation autour des murs à ajouter avant une production avancée.

**Lore** : les ennemis doivent être des formes de corruption propres aux Terres Féroces, pas des créatures empruntées à une franchise. Le jeu peut révéler ultérieurement s'ils sont sous influence de la Bête, du Dévoreur ou de commanditaires liés à Laetan.

## 6. Boucle de gameplay

1. **Préparer** : sélectionner héros et escouades, répartir les forces entre les accès.
2. **Assaut** : les ennemis apparaissent dans la jungle et progressent.
3. **Ordres** : déplacement, fixation de cible, tenue de position et activation des compétences.
4. **Résolution** : les unités combattent, encaissent et sont soignées ; l'Ancre peut perdre de l'intégrité.
5. **Accalmie** : temps bref pour repositionner et observer l'état du champ de bataille.
6. **Nouvelle vague** : augmentation de l'intensité.
7. **Fin** : victoire après la dernière vague si l'Ancre subsiste ; défaite si elle tombe ou si tous les défenseurs sont éliminés selon les règles du prototype.

**Structure actuelle** : **cinq vagues** et un objectif unique. Durée cible de **10–15 minutes**, à vérifier par test.

## 7. Commandes de la version HTML

| Action | Entrée prévue |
|---|---|
| Sélectionner une unité | Clic gauche |
| Sélection multiple | Maj + clic |
| Ordonner déplacement / attaque | Clic droit sur terrain / cible |
| Sélectionner héros ou escouade | Touches **1 à 6** |
| Sélectionner l'ensemble | **A** |
| Tenir position | **H** |
| Utiliser la compétence de la sélection | **Espace** |
| Recommencer | **R** |
| Déplacer la caméra | **ZQSD** ou **WASD** (attention au conflit entre **A** et sélection de tous) |
| Zoom | Molette |

**Point à corriger** : la touche **A** est simultanément documentée pour la sélection de tous et potentiellement utilisée par la caméra en mode WASD. Préférer **Ctrl + A** pour sélectionner tous, ou retirer WASD et n'utiliser que ZQSD sur disposition française.

## 8. Interface et retours visuels

La version jouable doit présenter :

- Nom du niveau et objectif.
- Numéro de vague et nombre d'ennemis restants.
- Pourcentage d'intégrité de l'Ancre.
- Six boutons de sélection : trois Exilés et trois escouades.
- Points de vie ou barres de résistance lisibles.
- Surbrillance des unités sélectionnées.
- État de disponibilité des compétences, idéalement avec temps de recharge.
- Indication des ordres donnés et messages brefs entre vagues.
- Écran de victoire/défaite et option de rejouer.

**Améliorations prioritaires** : tracer une ligne claire vers la destination, afficher la portée des armes à la sélection, signaler les unités bloquées, ajouter un retour d'impact aux tirs et une petite explosion à l'arrivée d'un carreau.

## 9. Direction artistique

### Monde

Science-fantasy sombre, jungle humide, clairière et chemin ancien, pierre monumentale tyrienne, motifs géométriques non religieux sur les machines, Ancre noire lumineuse par contraste.

### Exilés

Combinaison de technologie perdue et de silhouette chevaleresque originale. Métal sombre, argent, ivoire, cramoisi ; lueurs ambrées et bleu froid. Leurs équipements doivent être distincts des armes plus conventionnelles des disciples d'Indra.

### Tireuse

Rester fidèle aux intentions de la **planche produite dans la conversation** (vue face/profil/dos + détail de l'arbalète), **sans copier d'éléments reconnaissables d'une franchise tierce**. En vue isométrique, privilégier la silhouette et les contrastes plutôt que les micro-détails.

### Effets

- Arbalète : projectile visible, éclair bref à l'impact, explosion contenue.
- Rempart : arc protecteur lumineux, prise d'aggro lisible.
- Restaurateur : ondes et particules de réparation.
- Énonciation future : distorsion locale du mouvement et de l'espace, sans immobiliser nécessairement toute la simulation.

## 10. Fonctionnement technique du prototype actuel

Le fichier HTML autonome possède : une boucle de simulation, la gestion des unités et de leur vie, une sélection, des commandes de déplacement, des attaques automatiques, des compétences avec temps de recharge, des ennemis en vagues, une condition de victoire/défaite et un rendu isométrique Canvas.

**Limites connues** :

- Le rendu est une **projection 2D** et ne permet pas encore un véritable contrôle d'objets 3D.
- Les silhouettes sont stylisées et construites par primitives/dessin, sans fichiers `.glb`.
- L'IA et les obstacles ne disposent pas encore d'un système complet de navigation.
- Le ciblage et la gestion de la formation restent basiques.
- Les effets d'arme du Tireur ne mettent pas encore en œuvre un vrai système de détonation de zone avec projectiles simulés.
- Le soin, la gestion des escouades et les capacités temporelles nécessitent des tests de jouabilité plus poussés.

## 11. Backlog priorisé

### P0 — Sécuriser le prototype jouable

- [ ] Versionner le fichier `index.html` issu de la V3 corrigée.
- [ ] Tester un lancement par double-clic sur Windows/Chrome et Firefox.
- [ ] Vérifier démarrage sans écran noir ni erreurs de console.
- [ ] Vérifier sélection, clic droit, attaques, 5 vagues, victoire et défaite.
- [ ] Corriger conflit de touches « A » / WASD.
- [ ] Vérifier que les unités n'entrent pas visuellement dans des zones bloquées.

### P1 — Développer la Tireuse

- [ ] Silhouette lisible à trois niveaux de zoom.
- [ ] Orientation visuelle vers la cible.
- [ ] Animation stylisée de tir et de rechargement.
- [ ] Projectile visible avec petite détonation et dégâts de zone équilibrés.
- [ ] Compteur/rechargement du chargeur si cette complexité s'avère utile au gameplay.

### P1 — Renforcer le tactique

- [ ] Formations cohérentes pour trois escouades de quatre soldats.
- [ ] Améliorer priorité des cibles et règles tir/mêlée.
- [ ] Ajouter retour d'ordre et indicateur de portée.
- [ ] Avertir lorsque l'Ancre est attaquée.
- [ ] Rééquilibrer cinq vagues par sessions de test.

### P2 — Donner vie aux Exilés

- [ ] Améliorer visuellement Rempart et Restaurateur.
- [ ] Développer un premier pouvoir **d'Énonciation** : ralentissement local de zone.
- [ ] Introduire coût et temps de recharge du pouvoir.
- [ ] Ajouter un court journal narratif : mission, documents tyriens, indice sur Laetan.
- [ ] Clarifier le statut des disciples d'Indra et leur coopération avec les Exilés.

### P3 — Passage à une véritable 3D

- [ ] Choisir stack Three.js ou Godot Web selon cible de distribution.
- [ ] Reconstruire niveau 3D avec collisions et navigation.
- [ ] Importer meshes légers `.glb`, commencer par la Tireuse.
- [ ] Ajouter animations et niveaux de détail.
- [ ] Tester performances sur machine moyenne.

## 12. Critères d'acceptation du MVP

1. Le jeu s'ouvre dans un navigateur depuis le livrable annoncé, sans erreur bloquante.
2. La jungle, les deux entrées, le temple et l'Ancre sont immédiatement identifiables.
3. Trois Exilés distincts et trois escouades de quatre soldats sont contrôlables.
4. Les soldats peuvent attaquer au tir et en mêlée ; le Rempart engage au contact ; le Restaurateur soigne ; la Tireuse attaque à distance.
5. Au moins trois archétypes ennemis atteignent la zone défendue.
6. Cinq vagues s'enchaînent ; l'Ancre peut être endommagée.
7. Des messages explicites confirment victoire et défaite ; la partie peut recommencer.
8. Les contrôles sont visibles et ne se contredisent pas.
9. La Tireuse est visuellement distincte et son arbalète à répétition identifiable.
10. La partie ne nécessite aucune connaissance préalable du lore pour être comprise.

## 13. Trame narrative minimale en trois révélations

**Introduction — Le Serment :** les trois Exilés arrivent au Sanctum Lacertae en réponse à une anomalie. Les disciples d'Indra ont reçu mission de garder les accès. Une voix explique l'Ancre et leur devoir de protection.

**Milieu — Le prix du temps :** les inscriptions tyriennes et un dysfonctionnement de l'Ancre montrent que l'Énonciation modifie des propriétés physiques, mais que ces manipulations ont un coût pour leurs utilisateurs.

**Final — La signature :** un indice retrouvé sur les assaillants ou dans les archives indique qu'une autorité liée à Laetan connaissait l'existence du Sanctum. C'est une **accroche**, non une preuve que Laetan a personnellement commandé l'attaque : conserver le mystère.

## 14. Questions de lore à résoudre à travers le game design

- Pourquoi les disciples d'Indra sont-ils présents et que savent-ils de l'Ordre ?
- Quels matériaux alimentent une arbalète à répétition produite par les Exilés ?
- Les carreaux explosifs utilisent-ils un mécanisme chimique, physique ou l'Énonciation ?
- Comment le Restaurateur distingue-t-il soin biologique et retour spirituel ?
- Combien de temps un Exilé peut-il maintenir une altération temporelle ?
- Que se passe-t-il si l'Ancre est endommagée mais non détruite ?
- Qui décide de la mobilisation d'une cellule ?
- Quelles traces les Tyriens ont-ils laissées dans les archives du Sanctum ?

## 15. Arborescence de projet conseillée

```text
Exilesdefense/
├── index.html                         # prototype navigateur actuel
├── docs/
│   ├── LORE_TERRES_FEROCES_REFONDUES.md
│   └── GAME_DESIGN_EXILES_DEFENSE.md
├── assets/                            # futur : images, modèles, sons
│   ├── characters/
│   ├── environment/
│   └── audio/
└── README.md                          # lancement et commandes
```

Les deux documents sont **des références éditables**, indépendantes des fichiers d'exécution. Ils doivent être mis à jour après tout changement important de gameplay ou de canon.
