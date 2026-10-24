class_name Smoothing
## Frame-rate independent easing for cameras: the same motion at 30, 60 or 144 frames a second.


## How far to move toward a target this frame (0 to 1) to close most of the gap in about `time` seconds. A time of 0
## or less jumps straight there.
static func factor(delta: float, time: float) -> float:
	if time <= 0.0:
		return 1.0
	return 1.0 - exp(-delta / time)
