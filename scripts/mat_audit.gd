extends SceneTree
## Диагностический скрипт CI (запускается под xvfb с настоящим GL):
## печатает каждую загрузку материалов персонажа по отдельности —
## предупреждение Compatibility о subsurface scattering встаёт МЕЖДУ
## печатами и точно указывает виновника.


func _init() -> void:
	var mats := [
		"res://assets/Rosalie_Blackwood/materials/Body_Skin_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Cloth_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Dot_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Eye_Shadow_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Face_Skin_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Facial_Features_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Hair_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Iris_Color_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Iris_Higlights_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Jacket_Material.tres",
		"res://assets/Rosalie_Blackwood/materials/Raincoat_Material.tres",
	]
	for f in mats:
		print("[AUDIT] load ", f)
		var m: Material = load(f) as Material
		if m is BaseMaterial3D:
			var b: BaseMaterial3D = m
			print("[AUDIT]   BaseMaterial3D subsurf=", b.subsurf_scatter_enabled,
				" strength=", b.subsurf_scatter_strength,
				" skin=", b.subsurf_scatter_skin_mode)
		elif m != null:
			print("[AUDIT]   ", m.get_class())

	print("[AUDIT] load сцены персонажа")
	var ps: PackedScene = load("res://scenes/rosalie_blackwood.tscn")
	print("[AUDIT] instantiate")
	var node: Node = ps.instantiate()
	print("[AUDIT] перечисление материалов инстанса")
	var found: Array[Material] = []
	_collect(node, found)
	for m in found:
		var extra := ""
		if m is BaseMaterial3D:
			var b: BaseMaterial3D = m
			extra = " subsurf=%s strength=%.2f" % [str(b.subsurf_scatter_enabled), b.subsurf_scatter_strength]
		print("[AUDIT]   ", m.get_class(), " '", m.resource_name, "'", extra)
	node.free()
	print("[AUDIT] конец")
	quit(0)


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
