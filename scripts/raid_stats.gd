class_name RaidStats
extends RefCounted
## Bounded, in-memory raid measurements. No per-hit history, nodes, timers or saves.
enum Channel { NOSE, SIDES, PULSE, MINES }
enum Cause { CONTACT, SHELL, REEF, SHOAL, OTHER }
var dealt := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var evolution_times := PackedFloat64Array([-1.0, -1.0, -1.0, -1.0])
var received := 0.0
var debug_used := false
var incoming := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
var incoming_hits := PackedInt32Array([0, 0, 0, 0, 0])
var last_cause := -1
var last_hit_at := -1.0
var repairs := 0
var repaired := 0.0
var stern_unlocked_at := -1.0
var charges_dropped := 0
var charges_exploded := 0
var pulses := 0


func reset() -> void:
	dealt.fill(0.0)
	evolution_times.fill(-1.0)
	received = 0.0
	debug_used = false
	incoming.fill(0.0)
	incoming_hits.fill(0)
	last_cause = -1
	last_hit_at = -1.0
	repairs = 0
	repaired = 0.0
	stern_unlocked_at = -1.0
	charges_dropped = 0
	charges_exploded = 0
	pulses = 0


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


func record_received(cause: int, actual: float, seconds: float) -> void:
	if actual <= 0.0:
		return
	var index := cause if cause >= 0 and cause < incoming.size() else Cause.OTHER
	received += actual
	incoming[index] += actual
	incoming_hits[index] += 1
	last_cause = index
	last_hit_at = seconds
