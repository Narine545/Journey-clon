class_name RaidBoss
extends RefCounted
## Telegraph and firing use the same frozen attack snapshot.
const FAN_WARNING := 1.25
const RING_WARNING := 1.70
const ARRIVAL_GRACE := 1.20


static func phase(enemy: Dictionary) -> int:
	return 2 if float(enemy["hp"]) <= float(enemy["max_hp"]) * 0.5 else 1


static func preparing(enemy: Dictionary) -> bool:
	return float(enemy.get("boss_windup", 0.0)) > 0.0


static func directions(enemy: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var attack_phase: int = enemy.get("boss_attack_phase", 1)
	var aim: Vector2 = enemy.get("boss_aim", Vector2.UP)
	if int(enemy.get("boss_pattern", 0)) == 0:
		var half_count := 2 if attack_phase == 2 else 1
		for index in range(-half_count, half_count + 1):
			result.append(aim.rotated(float(index) * 0.28))
	else:
		var count := 12 if attack_phase == 2 else 10
		# Leave a gap toward the locked player bearing, not an unavoidable aimed wall.
		for index in range(count):
			result.append(aim.rotated((float(index) + 0.5) * TAU / float(count)))
	return result


static func shell_speed(enemy: Dictionary) -> float:
	if int(enemy.get("boss_pattern", 0)) == 0:
		return 12.0
	return 8.5 if int(enemy.get("boss_attack_phase", 1)) == 2 else 7.5


static func warning_length(enemy: Dictionary) -> float:
	return FAN_WARNING if int(enemy.get("boss_pattern", 0)) == 0 else RING_WARNING


static func step(enemy: Dictionary, delta: float, target: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not enemy.has("boss_cycle"):
		enemy["boss_cycle"] = 0
		enemy["boss_windup"] = 0.0
		enemy["boss_pattern"] = 0
		enemy["boss_aim"] = Vector2.UP
		enemy["boss_attack_phase"] = 1
		enemy["timer"] = ARRIVAL_GRACE
	if preparing(enemy):
		enemy["boss_windup"] = maxf(0.0, float(enemy["boss_windup"]) - delta)
		if not preparing(enemy):
			result = directions(enemy)
			enemy["timer"] = 2.6 if int(enemy["boss_attack_phase"]) == 2 else 3.1
			enemy["boss_cycle"] = int(enemy["boss_cycle"]) + 1
		return result
	enemy["timer"] = maxf(0.0, float(enemy["timer"]) - delta)
	if float(enemy["timer"]) <= 0.0:
		enemy["boss_pattern"] = int(enemy["boss_cycle"]) % 2
		enemy["boss_attack_phase"] = phase(enemy)
		var offset: Vector2 = target - enemy["at"]
		enemy["boss_aim"] = offset.normalized() if offset.length_squared() > 0.0001 else Vector2.UP
		enemy["boss_windup"] = warning_length(enemy)
	return result
