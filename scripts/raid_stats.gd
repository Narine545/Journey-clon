class_name RaidStats
extends RefCounted
## Bounded, in-memory raid measurements. No per-hit history, nodes, timers or saves.
enum Channel { NOSE, SIDES, PULSE, MINES }
var dealt := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var evolution_times := PackedFloat64Array([-1.0, -1.0, -1.0, -1.0])
var received := 0.0
var debug_used := false


func reset() -> void:
	dealt.fill(0.0)
	evolution_times.fill(-1.0)
	received = 0.0
	debug_used = false


func record_damage(channel: int, hp_before: float, power: float) -> void:
	if channel < 0 or channel >= dealt.size():
		return
	# Count only HP removed, not overkill or another hit on an already dead target.
	dealt[channel] += minf(maxf(0.0, hp_before), maxf(0.0, power))


func record_evolution(kind: int, seconds: float) -> void:
	var index := kind - 10
	if index >= 0 and index < evolution_times.size() and evolution_times[index] < 0.0:
		evolution_times[index] = seconds


func total_damage() -> float:
	var total := 0.0
	for value in dealt:
		total += value
	return total
