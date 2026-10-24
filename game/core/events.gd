extends Node
## The Events autoload: the game's event bus (project instructions, "Architecture"). Systems that care what happened
## elsewhere listen here instead of reaching into each other: the autosave, the HUD and, later, contracts and payouts
## hear that the ship docked or landed without knowing who docked it. Only signals live here; nothing is stored.

## The ship docked or landed at `port` (Arrivals.arrive, the one arrival function). It is held still there.
signal arrived(port: Port)
## The ship started leaving `port` (undocking or taking off).
signal departed(port: Port)
## The game was saved (`ok`), or a save failed and the last good save was kept.
signal game_saved(ok: bool)
