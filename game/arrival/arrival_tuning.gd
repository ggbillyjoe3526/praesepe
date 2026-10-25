class_name ArrivalTuning
extends Resource
## How the ship flies itself in to dock or land (design doc, "How docking and landing work"; Approach). Shared by
## every port; how close and slow a ship must be, where it lines up and how it leaves are each port's own (Port). The
## values and the reasons for them are in DESIGN.md, "Docking and landing tuning". Change a value there and here
## together.

## The fastest (m/s) it goes on the way, far from the port.
@export var top_speed: float = 400.0
## The push (m/s²) that changes its velocity on the way, and slows it before the final leg: the main engine's.
@export var travel_accel: float = 40.0
## At most this share of that push goes into curving (round a planet or station, or onto the final leg), which sets
## how fast it can go round close in; the rest slows it down on the way.
@export var curve_share: float = 0.5
## How gently (m/s²) it slows on the final leg, into the bay or down onto the pad.
@export var final_accel: float = 6.0
## The speed (m/s) it touches its berth at, as a soft bump in the camera.
@export var touch_speed: float = 1.5
## From this far (m) before the gate, it turns to the berth's attitude instead of facing where it is going.
@export var line_up_lead: float = 600.0
## Near the gate it cuts the corner onto the final leg, starting this far (m) from it.
@export var corner: float = 80.0
## Off to the side of the final leg, it closes the gap over this long (s), no faster than it takes the corner.
@export var side_time: float = 1.0
## Below the gate's height (round the planet or station) it climbs this many times as steeply as it would otherwise.
@export var climb: float = 3.0
## It closes the angle to the attitude it wants over this long (s), within the ship's own turn rates.
@export var turn_time: float = 0.8
## Lined up means within this angle (degrees) of the berth's attitude and this close (m) to the final leg's line;
## until then it holds this far (m) short of the berth on the final leg.
@export var lined_up_angle: float = 1.5
@export var on_line: float = 1.0
@export var hold_short: float = 60.0
## Turning round in a bay, it starts the second quarter turn once within this angle (degrees) of the first.
@export var quarter_tolerance: float = 10.0
## At the berth: within this (m) of it.
@export var arrive_distance: float = 0.05
## A ship up to this far (m) past its berth (sitting on the pad under the berth's marker) still takes the final leg.
@export var below_berth: float = 10.0
## A knock harder than this (m/s) on the way stops the approach and hands the ship back.
@export var bump_limit: float = 3.0


## How fast (m/s) it takes the corner onto the final leg: as fast as curve_share of its push can turn it round it.
func cornering_speed() -> float:
	return sqrt(curve_share * travel_accel * corner)
