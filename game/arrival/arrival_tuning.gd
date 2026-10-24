class_name ArrivalTuning
extends Resource
## How docking and landing look (design doc, "Docking and landing"): the transition screen's timing. Shared by every
## port; how close and slow a ship must be, and how it leaves, are each port's own (Port). The values and the reasons
## for them are in DESIGN.md, "Docking and landing tuning". Change a value there and here together.

## The view fades to black over this (s) once the pilot asks to dock or land.
@export var fade_out: float = 0.6
## It stays black this long (s), naming where the ship arrived and whether the game saved.
@export var hold: float = 1.4
## Then fades back in over this (s), the ship at its berth.
@export var fade_in: float = 0.6
