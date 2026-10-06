extends SceneTree
## Диагностический скрипт CI (запускается под xvfb с настоящим рендером):
## печатает загрузку сцен новых ассетов (зомби, руки с пистолетом)
## по отдельности — предупреждения рендера встают МЕЖДУ печатами
## и точно указывают виновника.


func _init() -> void:
	print("[AUDIT] load руки с пистолетом (Mark 23)")
	var arms_ps: PackedScene = load("res://assets/mark_23_animated/scene.gltf")
	if arms_ps != null:
		var arms: Node = arms_ps.instantiate()
		_dump(arms, "mark_23")
		arms.free()
	else:
		print("[AUDIT] !! сцена рук не загрузилась")

	print("[AUDIT] load зомби (Zombie De Goma)")
	var z_ps: PackedScene = load("res://assets/zombie_de_goma/scene.gltf")
	if z_ps != null:
		var z: Node = z_ps.instantiate()
		_dump(z, "zombie")
		z.free()
	else:
		print("[AUDIT] !! сцена зомби не загрузилась")

	print("[AUDIT] конец")
	quit(0)


func _dump(node: Node, tag: String) -> void:
	var found: Array[Material] = []
	_collect(node, found)
	var anims := 0
	for c in node.find_children("*", "AnimationPlayer", true, false):
		anims += (c as AnimationPlayer).get_animation_list().size()
	print("[AUDIT] %s: материалов %d, анимаций %d" % [tag, found.size(), anims])
	for m in found:
		var extra := ""
		if m is BaseMaterial3D:
			var b: BaseMaterial3D = m
			extra = " subsurf=%s" % str(b.subsurf_scatter_enabled)
		print("[AUDIT]   ", m.get_class(), " '", m.resource_name, "'", extra)


func _collect(n: Node, out: Array[Material]) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				_add(mi.mesh.surface_get_material(i), out)
		for i in range(mi.get_surface_override_material_count()):
			_add(mi.get_surface_override_material(i), out)
		_add(mi.material_override, out)
	for c in n.get_children():
		_collect(c, out)


func _add(m, out: Array[Material]) -> void:
	if m is Material:
		var cur: Material = m
		while cur != null and not out.has(cur):
			out.append(cur)
			cur = cur.next_pass
