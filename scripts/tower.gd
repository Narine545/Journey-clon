class_name ObservationTower
extends Node3D
## Геометрия — из исправленного GLB пользователя, дорожки — из прежнего
## анимированного экспорта. Координаты
## настила и якорей совпадают с площадкой M1; движение ограничивает TowerPlayer.
const DECK_HEIGHT := 52.0
const HALF_DECK := 6.0
const WALK_LIMIT := 5.35
const LIFT_OPENING_MIN_Z := 2.4
const LIFT_OPENING_MAX_Z := 4.6
const MODEL := preload("res://assets/tower/tower_delivery.glb")
# Границы авторской анимации кабины (центр якоря) и высота её пола
# относительно якоря. Линейно сохраняем форму движения, но совмещаем
# поверхность пола с землёй внизу и настилом на высоте 52 м наверху.
const SOURCE_CAGE_BOTTOM := 1.511598
const SOURCE_CAGE_TOP := 54.711597
const FLOOR_BELOW_ANCHOR := 1.2926
var model: Node3D
var animation: AnimationPlayer
var cage_track := ""
var door_track := ""
var cage_anchor: Node3D
var lift_gate: StaticBody3D
var lift_gate_shape: CollisionShape3D
var dock_body: StaticBody3D
var lift_access_open := false


func _ready() -> void:
	_build_deck_collisions()
	model = MODEL.instantiate() as Node3D
	model.name = "AnimatedTower"
	add_child(model)
	_prepare_lift_opening()
	_build_structure_collisions()
	cage_anchor = model.find_child("*CAGE*center*", true, false) as Node3D
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation == null or cage_anchor == null:
		push_error("В модели башни отсутствует AnimationPlayer или якорь кабины")
		return
	# Имена в glTF могут быть нормализованы импортёром Godot, поэтому
	# выбираем дорожки по стабильным названиям якорей Blender.
	for track in animation.get_animation_list():
		var normalized := String(track).to_lower()
		if "cage_center" in normalized:
			cage_track = String(track)
		elif "door_center" in normalized:
			door_track = String(track)
	if cage_track.is_empty() or door_track.is_empty():
		push_error("В модели башни не найдены дорожки лифта и дверцы: %s" % str(animation.get_animation_list()))
		return
	# В Blender 60 кадров/с: кадр 120 — нижнее положение, 240 — верхнее,
	# кадр 300 — дверца открыта, 360 — закрыта.
	# После переключения дорожки Godot может восстановить остальные узлы к
	# исходной позе файла (в ней кабина наверху). Нижнюю позицию выставляем
	# последней, а закрытая дверца совпадает с исходной позой.
	pose_door(6.0)
	pose_cage(2.0)


## Авторские сплошные прутья с северной стороны пересекали дверной проём.
## Не меняем исходный GLB: прячем их только в игровой сцене и воссоздаём
## обе части за пределами шахты с тем же материалом и размером.
func _prepare_lift_opening() -> void:
	for rail_name in ["RailX_N_0*46m", "RailX_N_1*26m"]:
		var original := model.find_child(rail_name, true, false) as MeshInstance3D
		if original == null:
			push_error("Не найдены перила проёма лифта: " + rail_name)
			continue
		original.visible = false
		var material := original.get_active_material(0)
		var rail_y := original.global_position.y - global_position.y
		_add_opening_rail("RailX_N_Opening_" + str(int(rail_y * 100)) + "_left", rail_y, -6.0, LIFT_OPENING_MIN_Z, material)
		_add_opening_rail("RailX_N_Opening_" + str(int(rail_y * 100)) + "_right", rail_y, LIFT_OPENING_MAX_Z, 6.0, material)
	var obstructing_post := model.find_child("RailPostX_N_3", true, false) as MeshInstance3D
	if obstructing_post != null:
		obstructing_post.visible = false
	else:
		push_error("Не найдена стойка внутри проёма лифта")


func _add_opening_rail(part_name: String, height: float, from_z: float, to_z: float, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = part_name
	var box := BoxMesh.new()
	box.size = Vector3(0.10, 0.10, to_z - from_z)
	visual.mesh = box
	visual.material_override = material
	visual.position = Vector3(-5.95, height, (from_z + to_z) * 0.5)
	model.add_child(visual)


## Статические детали авторского GLB: отдельные коробки по реальным AABB и
## трансформациям узлов, а не невидимая сплошная стена вокруг башни. Подвижную
## кабину/дверцу не включаем: их положение управляется отдельной анимацией.
func _build_structure_collisions() -> void:
	var body := StaticBody3D.new()
	body.name = "TowerStructureCollisions"
	body.collision_layer = 8
	body.collision_mask = 0
	add_child(body)
	var prefixes := ["Support_", "Footing_", "CrossBrace_", "SupportRing_", "LiftShaft_", "LiftCrossbar_", "DeckRim_", "RailX_", "RailZ_", "RailPostX_", "RailPostZ_"]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part == null or part.mesh == null or not part.visible or _is_animated_cage_part(part):
			continue
		var selected := false
		for prefix in prefixes:
			if String(part.name).begins_with(prefix):
				selected = true
				break
		if not selected:
			continue
		var local_transform := global_transform.affine_inverse() * part.global_transform
		var bounds := part.mesh.get_aabb()
		var part_scale := local_transform.basis.get_scale().abs()
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
			continue
		var box := BoxShape3D.new()
		box.size = bounds.size * part_scale
		var collider := CollisionShape3D.new()
		collider.name = "Collision_" + String(part.name)
		collider.shape = box
		collider.transform = Transform3D(local_transform.basis.orthonormalized(), local_transform * bounds.get_center())
		body.add_child(collider)


## Кабина и её дверца являются потомками анимируемого якоря. Нельзя
## запекать их текущее положение в неподвижный коллайдер шахты.
func _is_animated_cage_part(part: Node) -> bool:
	var ancestor: Node = part
	while ancestor != null and ancestor != model:
		if "ANCHOR_LIFT_CAGE" in String(ancestor.name).to_upper():
			return true
		ancestor = ancestor.get_parent()
	return false


## Физические прокси пока только для площадки: пол, безопасные границы и
## радиостойка. Слои не участвуют в лучах выстрела и взаимодействия с грузом.
func _build_deck_collisions() -> void:
	var body := StaticBody3D.new()
	body.name = "DeckCollisions"
	body.collision_layer = 8
	body.collision_mask = 0
	add_child(body)
	_add_box(body, Vector3(0, DECK_HEIGHT - 0.1, 0), Vector3(12.0, 0.2, 12.0))
	# Без троса невидимые границы по-прежнему защищают от случайного падения.
	# Крюк временно отключает только их, не пол и не радиостойку.
	var barriers := StaticBody3D.new()
	barriers.name = "DeckBarriers"
	barriers.collision_layer = 64
	barriers.collision_mask = 0
	add_child(barriers)
	for side in [-1.0, 1.0]:
		if side > 0.0:
			_add_box(barriers, Vector3(side * 5.9, DECK_HEIGHT + 2.0, 0), Vector3(0.4, 4.0, 12.0))
		else:
			_add_box(barriers, Vector3(-5.9, DECK_HEIGHT + 2.0, (-6.0 + LIFT_OPENING_MIN_Z) * 0.5), Vector3(0.4, 4.0, LIFT_OPENING_MIN_Z + 6.0))
			_add_box(barriers, Vector3(-5.9, DECK_HEIGHT + 2.0, (LIFT_OPENING_MAX_Z + 6.0) * 0.5), Vector3(0.4, 4.0, 6.0 - LIFT_OPENING_MAX_Z))
		_add_box(barriers, Vector3(0, DECK_HEIGHT + 2.0, side * 5.9), Vector3(12.0, 4.0, 0.4))
	_build_lift_safety()
	_add_box(body, Vector3(-4.75, DECK_HEIGHT + 0.46, -3.9), Vector3(1.15, 0.92, 1.0))
	# Прокси по верхнему краю для прицеливания крюком, отдельный слой не
	# вмешивается в выстрелы и физику игрока. Чуть снаружи настила, чтобы
	# при подъёме трос не затягивал игрока сквозь пол снизу.
	var anchors := StaticBody3D.new()
	anchors.name = "GrappleAnchors"
	anchors.collision_layer = 32
	anchors.collision_mask = 0
	add_child(anchors)
	var anchor_material := StandardMaterial3D.new()
	anchor_material.albedo_color = Color(0.72, 0.57, 0.25)
	anchor_material.metallic = 0.45
	anchor_material.roughness = 0.6
	for side in [-1.0, 1.0]:
		_add_box(anchors, Vector3(side * 6.25, DECK_HEIGHT + 3.5, 0), Vector3(0.7, 0.7, 12.5))
		_add_box(anchors, Vector3(0, DECK_HEIGHT + 3.5, side * 6.25), Vector3(12.5, 0.7, 0.7))
		# Тонкие временные рейки показывают, куда целиться с земли.
		_add_anchor_visual(Vector3(side * 6.25, DECK_HEIGHT + 3.5, 0), Vector3(0.12, 0.12, 12.5), anchor_material)
		_add_anchor_visual(Vector3(0, DECK_HEIGHT + 3.5, side * 6.25), Vector3(12.5, 0.12, 0.12), anchor_material)
		for cross_side in [-1.0, 1.0]:
			# От настила/угловых стоек к самой раме — без висящих в воздухе концов.
			_add_anchor_support(Vector3(side * 5.95, DECK_HEIGHT + 0.1, cross_side * 5.95), Vector3(side * 6.25, DECK_HEIGHT + 3.5, cross_side * 6.25), anchor_material)


## До прибытия и полного открытия двери проём защищён видимым ограждением.
## При открытии его заменяет физический пол и ограждения стоящей кабины.
func _build_lift_safety() -> void:
	lift_gate = StaticBody3D.new()
	lift_gate.name = "LiftSafetyGate"
	lift_gate.collision_layer = 8
	lift_gate.collision_mask = 0
	add_child(lift_gate)
	var gate_box := BoxShape3D.new()
	gate_box.size = Vector3(0.18, 4.0, LIFT_OPENING_MAX_Z - LIFT_OPENING_MIN_Z)
	lift_gate_shape = CollisionShape3D.new()
	lift_gate_shape.shape = gate_box
	lift_gate_shape.position = Vector3(-5.95, DECK_HEIGHT + 2.0, 3.5)
	lift_gate.add_child(lift_gate_shape)
	var gate_material := StandardMaterial3D.new()
	gate_material.albedo_color = Color(0.48, 0.39, 0.24)
	gate_material.metallic = 0.55
	for height in [0.46, 1.26]:
		var bar := MeshInstance3D.new()
		var beam := BoxMesh.new()
		beam.size = Vector3(0.12, 0.12, LIFT_OPENING_MAX_Z - LIFT_OPENING_MIN_Z)
		bar.mesh = beam
		bar.material_override = gate_material
		bar.position = Vector3(-5.95, DECK_HEIGHT + height, 3.5)
		lift_gate.add_child(bar)
	dock_body = StaticBody3D.new()
	dock_body.name = "DockedLiftSafety"
	dock_body.collision_layer = 8
	dock_body.collision_mask = 0
	add_child(dock_body)
	# Пол точно на высоте настила; стенки удерживают игрока в кабине.
	_add_box(dock_body, Vector3(-7.25, DECK_HEIGHT - 0.1, 3.5), Vector3(2.9, 0.2, 2.2))
	_add_box(dock_body, Vector3(-8.65, DECK_HEIGHT + 1.8, 3.5), Vector3(0.18, 3.6, 2.3))
	for z in [LIFT_OPENING_MIN_Z, LIFT_OPENING_MAX_Z]:
		_add_box(dock_body, Vector3(-7.25, DECK_HEIGHT + 1.8, z), Vector3(2.9, 3.6, 0.18))
	for child in dock_body.get_children():
		(child as CollisionShape3D).disabled = true


func set_lift_access(open: bool) -> void:
	if lift_access_open == open:
		return
	lift_access_open = open
	lift_gate.visible = not open
	# Отложенное обновление безопасно и при вызове из физического кадра.
	lift_gate_shape.set_deferred("disabled", open)
	for child in dock_body.get_children():
		(child as CollisionShape3D).set_deferred("disabled", not open)


## Опоры соединены с видимыми угловыми стойками башни и сами останавливают тело.
func _add_anchor_support(start: Vector3, end: Vector3, material: Material) -> void:
	var span := end - start
	var local_transform := Transform3D(Basis(Quaternion(Vector3.UP, span.normalized())), (start + end) * 0.5)
	var dimensions := Vector3(0.12, span.length(), 0.12)
	var support := StaticBody3D.new()
	support.name = "GrappleFrameSupport_%s_%s" % ["P" if start.x > 0.0 else "N", "P" if start.z > 0.0 else "N"]
	support.collision_layer = 8
	support.collision_mask = 0
	support.transform = local_transform
	add_child(support)
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collider := CollisionShape3D.new()
	collider.shape = shape
	support.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	support.add_child(visual)


func _add_anchor_visual(at: Vector3, size: Vector3, material: Material) -> void:
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.material_override = material
	visual.position = at
	add_child(visual)


func _add_box(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	body.add_child(collider)


func pose_cage(time: float) -> void:
	_pose(cage_track, time)
	if cage_anchor != null:
		var fraction := clampf((cage_anchor.position.y - SOURCE_CAGE_BOTTOM) / (SOURCE_CAGE_TOP - SOURCE_CAGE_BOTTOM), 0.0, 1.0)
		cage_anchor.position.y = FLOOR_BELOW_ANCHOR + DECK_HEIGHT * fraction


func pose_door(time: float) -> void:
	_pose(door_track, time)
	# Эта дорожка проигрывается только на верхней площадке. При переключении
	# Godot может восстановить исходную высоту узла, поэтому выставляем её.
	if cage_anchor != null:
		cage_anchor.position.y = FLOOR_BELOW_ANCHOR + DECK_HEIGHT


func _pose(track: String, time: float) -> void:
	if animation == null or track.is_empty():
		return
	animation.play(track)
	animation.seek(time, true)
	animation.pause()
