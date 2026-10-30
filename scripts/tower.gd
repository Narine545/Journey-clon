class_name ObservationTower
extends Node3D
## Модель пользователя экспортирована из Blender 5 в glTF. Координаты
## настила и якорей совпадают с площадкой M1; движение ограничивает TowerPlayer.
const DECK_HEIGHT := 52.0
const HALF_DECK := 6.0
const WALK_LIMIT := 5.35
const MODEL := preload("res://assets/tower/animated_tower.glb")
var model: Node3D
var animation: AnimationPlayer
var cage_track := ""
var door_track := ""


func _ready() -> void:
	model = MODEL.instantiate() as Node3D
	model.name = "AnimatedTower"
	add_child(model)
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation == null:
		push_error("В модели башни отсутствует AnimationPlayer")
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
	pose_cage(2.0)
	pose_door(6.0)


func pose_cage(time: float) -> void:
	_pose(cage_track, time)


func pose_door(time: float) -> void:
	_pose(door_track, time)


func _pose(track: String, time: float) -> void:
	if animation == null or track.is_empty():
		return
	animation.play(track)
	animation.seek(time, true)
	animation.pause()
