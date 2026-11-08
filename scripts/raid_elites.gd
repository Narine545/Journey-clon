class_name RaidElites
extends RefCounted
## Three optional encounters, driven only by combat time. No backlog after blocked water.
const TIMES := [65.0, 130.0, 195.0]
const WINDOW := 12.0
const RETRY := 1.0
const HP_SCALE := 2.8
const RADIUS_SCALE := 1.35
const REWARD := 8
var cursor := 0
var retry_at := 0.0


func reset() -> void:
	cursor = 0
	retry_at = 0.0


func due(seconds: float, enemies: Array) -> bool:
	while cursor < TIMES.size() and seconds >= float(TIMES[cursor]) + WINDOW:
		cursor += 1
	if cursor >= TIMES.size() or seconds < float(TIMES[cursor]) or seconds < retry_at:
		return false
	for enemy in enemies:
		if bool(enemy.get("elite", false)):
			return false
	return true


func attempted(seconds: float, success: bool) -> void:
	if success:
		cursor += 1
	else:
		retry_at = seconds + RETRY


static func reward(enemy: Dictionary) -> int:
	if int(enemy["kind"]) == 3:
		return 0
	if bool(enemy.get("elite", false)):
		return REWARD
	return 4 if int(enemy["kind"]) == 2 else 2
