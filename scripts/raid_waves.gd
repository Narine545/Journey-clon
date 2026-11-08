class_name RaidWaves
extends RefCounted
## Pure schedule driven by raid time, never wall-clock time or the inspection camera.
# Start, label, interval in seconds, ordinary ranged-enemy cap.
const PHASES := [
	[0.0, "I · ПЕРВЫЙ КОНТАКТ", 1.05, 2],
	[60.0, "II · НАТИСК", 0.80, 3],
	[120.0, "III · ОКРУЖЕНИЕ", 0.60, 4],
	[180.0, "IV · ШТОРМОВОЙ ФРОНТ", 0.45, 5],
	[225.0, "ПЕРЕДЫШКА ПЕРЕД БОССОМ", 1.10, 0],
	[240.0, "V · КРУПНАЯ ЦЕЛЬ", 1.10, 0],
]


static func phase(seconds: float) -> int:
	var result := 0
	for index in range(1, PHASES.size()):
		if seconds >= float(PHASES[index][0]):
			result = index
	return result


static func label(seconds: float) -> String:
	return String(PHASES[phase(seconds)][1])


static func interval(seconds: float) -> float:
	return float(PHASES[phase(seconds)][2])


static func ranged_cap(seconds: float) -> int:
	return int(PHASES[phase(seconds)][3])


static func respite(seconds: float) -> bool:
	return seconds >= 225.0 and seconds < 240.0


static func choose_kind(seconds: float, ranged_count: int, roll: float) -> int:
	if seconds < 15.0:
		return 0
	if seconds >= 35.0 and roll < 0.16 and ranged_count < ranged_cap(seconds):
		return 2
	return 1 if roll < 0.48 else 0
