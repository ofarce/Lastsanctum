# Animations ennemies validées

36 atlas PNG : repos, marche, attaque et mort pour neuf ennemis. Le gabarit vivant est de 40 × 42 pixels ; les chutes disposent d'une marge pour le corps et les armes au sol. Ancres, cadence et découpage sont dans `manifest.json`.

Le générateur est celui de `planches/ennemis-animations.html`, incluant `death-rig.js`. Les quatre anciennes marches et leurs repos proviennent des atlas du baker, sans redessin. Ne pas retoucher les atlas manuellement.

Exception : la marche du Strazhar est à quatre pattes (« La ruée », choix 04 de `planches/strazhar-quadrupede-propositions.html`). Elle vient de `planches/ennemis/strazhar-quadrupede-v3.js`, exportée par le même bouton, dans un cadre de 68 × 48 avec son ancre propre (`walk.ax`, `walk.ay` dans le manifeste, lus par `UnitView` pendant la marche). Sa foulée est de 4,125 unités, soit 33 px natifs par cycle, pour que les poings ne glissent pas. Le repos, l'attaque et la mort du Strazhar restent debout.

Pour régénérer depuis la racine du projet :

```sh
python3 tools/export_enemy_animations.py
```

Ouvrir `http://127.0.0.1:8791/planches/ennemis-animations.html?export=1` et cliquer sur « Exporter les animations Godot ». Attendre « Export terminé : 9 ennemis, 36 atlas », puis réimporter dans Godot.

Les références de `assets/baked/enemies/` restent intactes. Les statistiques de combat sont dans `data/catalog.gd`. Les renforts entrent progressivement aux assauts 2 (éclaireur), 3 (soldat), 4 (archer), 5 (bouclier). Un Strazhar ouvre chaque assaut dès 1 000 de Menace ou à partir de la vague 8. La Menace est relevée au lancement de la vague ; une file déjà préparée reste inchangée. Le budget global de puissance des vagues n'est pas modifié par cette règle d'apparition.

## Refonte 16 bits (2026-11-19)

Fanatique, Thuriféraire, éclaireur, soldat, bouclier, archer, Bête, félin et crocodile viennent maintenant de
`planches/refonte-16bits-export.html` (dessin `planches/assets/refonte-16bits.js`, même moteur que l'Ingénieur).
Gabarit humain 40 × 42, pieds en (15, 40), mort 60 × 47 ; bêtes 48 × 30, pieds propres à chaque espèce. Pour
régénérer : `python3 tools/refonte/serve.py`, puis ouvrir `http://127.0.0.1:8179/planches/refonte-16bits-export.html?save=1`
(écrit aussi la caserne : lame, archer, flammes). La Brute, le Strazhar et la Martyre ne changent pas.

## Poses intermédiaires (2026-11-19)

Même générateur, mêmes gabarits et mêmes nombres d'images ; seules les poses changent pour les neuf ennemis de la refonte :
marche sur 12 phases par foulée (pas jusqu'à 2 px, appuis tenus ; `ph` dans `fig` / `quad`), respiration en trois temps
(la tête mène la descente, le buste la remontée), attaques avec élan (`mid`), traînée d'estoc qui s'efface (`fade`) et
retour de garde (`rec`), flamme du Thuriféraire qui vacille, corde de l'archer qui vibre, morsure des bêtes en deux temps
(`reach`, `jaw`) et queue qui balance au repos (`tw`). La caserne (lame, archer, flammes) sort identique au pixel près.
`UnitView` rend la main au repos dès la dernière image distincte d'une attaque (comparaison en alpha prémultiplié).
Chaque phase de marche est distincte (pied levé sur la jambe qui passe, bras en retard, choc de la tête au contact) :
10 à 12 poses par foulée au lieu de 3.

Brute et Strazhar (`planches/ennemis/animation-lab.js`) : la marche de la Brute est dessinée par le modèle sur 24 poses
au lieu des 6 de l'atlas du baker (`PROC_WALK`, `self_bob` à vrai) ; le repos du Strazhar respire (`breathe`, mêmes trois
temps). `animationLab.exportSheet(unité, action)` rend un seul atlas ; l'export complet de cette page réécrit tout le
manifeste et écraserait la refonte : n'exporter que les atlas voulus.

## Chiens de la Bête HD (2026-11-19)

`beast_*` vient du modèle C « Charognard aux trois gueules » de `planches/chiens-bete-propositions.html`
(dessin `planches/assets/bete/chiens-bete.js`). Cadre 84 × 48, ancre (36, 44) ; repos 48 images en boucle (2 s),
charge 12 (0,5 s, foulée 4,125 unités), bond 18 (0,75 s, impact image 15), mort 36 (éclatement en cendres, 1,5 s).
Pour régénérer : `python3 tools/chiens/export_beast.py` (Firefox headless, aucun serveur), puis réimporter dans Godot.
La vitesse de `beast` (`data/catalog.gd`) est passée à 6,3 pour que la charge ne glisse pas.

Planche de contrôle : `python3 tools/bestiaire/build.py` régénère `planches/bestiaire-anime.html` (avant / après,
cadences du jeu, nervosité de `UnitView`). Les atlas « avant » sont gardés dans `tools/bestiaire/avant/`.

## Mise à jour des unités (2026-11-19)

Pistes retenues de `planches/unites-maj-propositions.html` (générateur `tools/unites-maj/build.py`), exportées par
`planches/refonte-16bits-export.html` :

- formes-signatures des soldats de Laetan (`FIG` : `scarf`, `pike`, `pavois`, `longbow`) ; crocodile et félin enrichis
  (`QUAD.rich`) ;
- repos de 48 images à 12 i/s avec un geste d'attente par rôle (`WAIT`), tirs décomposés (`ATTACK`), coup encaissé
  `<type>_hit.png` (6 images, joué par `UnitView` sur les gros coups, au plus toutes les 0,6 s), morts d'une trentaine
  de poses ;
- Caserne : mêmes animations, jambes allongées (`tall`), échelle 1 dans le jeu (`adepts.roles.<rôle>.scale`), marche à
  la foulée (`stride`), atlas `death` et `hit` joués par `AdeptView` et `AllyDeathFx`.

Le chien de la Bête n'est plus touché par cet export (`tools/chiens/export_beast.py` seulement). Sans serveur d'aperçu :
`?save=sync` envoie tout en XHR synchrones, ce qui permet l'export par Firefox headless (voir le lanceur décrit dans
`tools/unites-maj/README.md`). Les atlas d'avant cette mise à jour sont gardés dans `tools/unites-maj/avant/`.

Brute et Strazhar : dessin inchangé. Leur coup est annoncé (`Catalog.ENEMY_WINDUP`, `UnitView.ATTACK_IMPACT`) : la
simulation retarde les dégâts de 0,4 s et 0,25 s, et la cible sortie de portée entre-temps esquive.

## Brute et Strazhar au standard de la refonte (2026-11-19)

Choix de `planches/brute-strazhar-propositions.html` : Brute **B · Colosse cuirassé** (cadre 48 × 46, ancre 24,43),
Strazhar **A · Champion couronné**, à quatre pattes dans toutes ses animations (cadre 68 × 48, ancre 33,45, plus
d'ancre propre à la marche). Dessin : `planches/assets/boss/brute-strazhar.js`. Atlas `idle` (boucle), `walk`,
`attack` (armement tenu, choc à 0,40 s et 0,25 s = `Catalog.ENEMY_WINDUP`), `hit`, `death`.

    python3 tools/unites-maj/export_g1.py && godot --headless --path . --import

Ne plus exporter ces deux ennemis depuis `planches/ennemis-animations.html` (ancien dessin).
