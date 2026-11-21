extends Node
## Bus de signaux global (autoload « Events »).
## Découple la simulation, le rendu et le HUD : les émetteurs n'ont pas besoin
## de connaître les récepteurs. Les signaux sont ajoutés au fil des étapes de
## MIGRATION_PLAN.md ; ne déclarer ici que ceux qui sont réellement émis.

## Message bref au centre de l'écran (équivalent de say() dans Index.html:78).
signal notice(text: String, seconds: float)

## Alerte de vague (ui/hud/hud.gd) : texte rouge en bas à gauche, au-dessus de la minicarte, puis fondu.
signal wave_alert(text: String, seconds: float)

## La partie vient d'être (ré)initialisée (équivalent de init(), Index.html:75).
signal game_reset

## Demande d'ouverture de l'inventaire (clic droit sur le coffre antique déjà ouvert).
signal inventory_requested

## Fin de partie (end(won), Index.html) : la simulation est figée et la bannière s'affiche.
signal game_over(won: bool)

## Bruitage à jouer (ui/audio/sfx_player.gd) : nom du fichier dans assets/audio/sfx/ sans extension, volume en dB.
signal sfx(name: String, volume_db: float)

## Bruitage au volume du catalogue (SfxPlayer.VOLUME_DB), pour l'interface et les cinématiques.
signal sound(name: String)

## Bruitage situé dans le monde (x, z) : joué seulement si le point est dans le champ de la caméra,
## après `delay` secondes (impact d'un projectile en vol, par exemple).
signal sound_at(name: String, x: float, z: float, delay: float)

## Objets remis au joueur (ui/banner/item_banner.gd) : une bannière « Reçu : … » par objet, enchaînées à chaque action.
signal items_received(items: Array)

## Objets ramassés par l'Exilé (corps, caches, sol) : une ligne « icône Nom ×N » en haut à gauche (ui/hud/loot_feed.gd).
signal loot_picked(item: String, count: int)

signal production_chest_requested(building: Building, kind: String, engineer: Unit)
