# Casernes d’Indra — cinq propositions animées

Ouvrir [la planche](../../caserne-propositions.html). Dessins natifs Canvas, comme les planches scierie et fonderie du projet. La référence jointe inspire les cours ouvertes, la pierre tyrienne, les tours, les râteliers et les bannières rouges au trident.

1. Cour du Trident : enceinte de pierre et trois tours.
2. Camp des vétérans : palissades et tentes.
3. Cloître martial : galeries couvertes autour du cercle.
4. Bastion d’Indra : donjons hauts et murs renforcés.
5. Arène des recrues : socle octogonal et gradins.

Cycle illustratif de 32 secondes : construction 0–6 s ; instructeur créé à 6 s à la lisière en bas à droite (300,227) ; marche interpolée jusqu’au centre (160,177) à 11 s ; entraînement sur mannequin avec garde, armement, frappe, trace d’épée et récupération. Trois soldats sont formés à 17, 23 et 29 s et sortent de la cour. Leur modèle simplifié reprend l’armure et les couleurs d’Indra sans cimier. Le compteur se réinitialise au prochain cycle.

Le modèle commun d’instructeur expose marche, garde et entraînement. Pause, vitesse et curseur permettent l’examen ; les préférences de mouvement réduit activent la pause au chargement. Rendu en résolution triple, positions et articulations continues via requestAnimationFrame.

API : `BarracksKit.DESIGNS`, `state(time)`, `render(context, design, time)`, `actor(context,x,y,time,mode,scale,recruit)`, `building(context,design,time)` dans `../../assets/barracks.js`.

Cette étude ne modifie pas la partie. Le recrutement des anciens soldats d’Indra n’est pas encore rétabli dans le jeu principal ; le modèle et la séquence de formation sont préparés pour la proposition retenue. Coûts, statistiques et cadence de jeu restent à définir.

Validation : `python3 tests/barracks_browser_smoke.py` ; 60 rendus, cinq variantes, arrivée au centre, trois soldats à 29 s, curseur et pause ; aucune erreur JavaScript. Capture `apercu.png` vérifiée visuellement.

## Reprise visuelle

Architectures redessinées : camp à tentes et une vigie, cloître à grande couverture et colonnes, bastion à porte centrale et deux donjons, arène à gradins et vélum. Maçonnerie par assises, toitures à plusieurs pans, auvents rayés, râteliers, boucliers et lisière arborée ajoutés. Modèle d’instructeur enrichi (épaulières, cuirasse articulée, ceinture, heaume). Présentation en trois propositions puis deux, aperçu animé directement à 14 s ; « Rejouer la construction » revient à 0 s. Validation Chromium répétée : 60 rendus sans erreur.
