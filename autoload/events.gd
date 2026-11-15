extends Node
## Bus de signaux global (autoload « Events »).
## Découple la simulation, le rendu et le HUD : les émetteurs n'ont pas besoin
## de connaître les récepteurs. Les signaux sont ajoutés au fil des étapes de
## MIGRATION_PLAN.md ; ne déclarer ici que ceux qui sont réellement émis.

## Message bref au centre de l'écran (équivalent de say() dans Index.html:78).
signal notice(text: String, seconds: float)

## La partie vient d'être (ré)initialisée (équivalent de init(), Index.html:75).
signal game_reset

## Fin de partie (end(won), Index.html) : la simulation est figée et la bannière s'affiche.
signal game_over(won: bool)
