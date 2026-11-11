class_name GravityMines
extends SphereMines
## Separate weapon: bounded radial acceleration, continuous damage, then outward release.


func weapon_rank() -> int:
	return run.gravity_rank


func field_duration() -> float:
	return 3.0 + float(run.gravity_stability)


func release_interval() -> float:
	return 10.0 - float(clampi(weapon_rank(), 1, 3) - 1)


func drop_offset() -> Vector2:
	return run.forward().orthogonal() * 3.0


func record_drop() -> void:
	run.stats.gravity_dropped += 1


func record_open() -> void:
	run.stats.gravity_opened += 1


func _drop() -> void:
	var previous_count := mines.size()
	super._drop()
	if mines.size() > previous_count:
		var mine := mines.back()
		mine["dps"] = 8.0 + 4.0 * float(run.gravity_damage_rank)
		mine["released"] = false
		var node: MeshInstance3D = mine["node"]
		var material := node.mesh.material as ShaderMaterial
		material.set_shader_parameter("gravity_field", true)


func _expansion_contacts(mine: Dictionary, before: float, after: float) -> void:
	var end := FUSE + float(mine["duration"]) - 0.4
	var active_delta := maxf(0.0, minf(after, end) - maxf(before, FUSE + 0.3))
	var releasing := after >= end and before < end and not bool(mine["released"])
	if releasing:
		mine["released"] = true
	if active_delta <= 0.0 and not releasing:
		return
	var center: Vector2 = mine["at"]
	var reach := float(mine["radius"])
	for enemy in run.enemies:
		if float(enemy["hp"]) <= 0.0 or float(enemy.get("born", 0.0)) > 0.0:
			continue
		var enemy_at: Vector2 = enemy["at"]
		var offset := enemy_at - center
		var distance := offset.length()
		if distance > reach + float(enemy["radius"]):
			continue
		if not run.stern_charges._line_clear(center, enemy_at):
			continue
		var normal := (
			offset / distance
			if distance > 0.001
			else Vector2.from_angle(float(enemy["combat_id"]) * 2.399963)
		)
		var external: Vector2 = enemy.get("sphere_velocity", Vector2.ZERO)
		# Soft center: acceleration vanishes at center, no positional snapping or orbit rail.
		var acceleration := -normal * 18.0 * minf(1.0, distance / 1.5)
		var change := acceleration * RaidMotion.inverse_mass(enemy) * active_delta
		if releasing:
			change += normal * 9.0 * RaidMotion.inverse_mass(enemy)
			enemy["sphere_recovery"] = 1.0
		if change.length() >= 0.05:
			enemy["sphere_recovery"] = 1.0
			if int(enemy.get("kind", 0)) == 1:
				enemy["charge"] = 0.0
				enemy["timer"] = maxf(1.6, float(enemy.get("timer", 0.0)))
		enemy["sphere_velocity"] = external + change
		# Damage only while the target's center is actually inside, never on release alone.
		if distance <= reach and active_delta > 0.0:
			var power := float(mine["dps"]) * active_delta
			run.stats.record_damage(RaidStats.Channel.GRAVITY, float(enemy["hp"]), power)
			enemy["hp"] = maxf(0.0, float(enemy["hp"]) - power)
