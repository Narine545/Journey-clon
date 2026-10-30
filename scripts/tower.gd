class_name ObservationTower
extends Node3D
## Геометрия — из исправленного GLB пользователя, дорожки — из прежнего
## анимированного экспорта. Координаты
## настила и якорей совпадают с площадкой M1; движение ограничивает TowerPlayer.
const DECK_HEIGHT := 52.0
const HALF_DECK := 6.0
const WALK_LIMIT := 5.35
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


func _ready() -> void:
	model = MODEL.instantiate() as Node3D
	model.name = "AnimatedTower"
	add_child(model)
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
