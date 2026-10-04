class_name FootPlant
extends SkeletonModifier3D
## Посадка стоп по рельефу. Анимация ходьбы ассета сделана для ровного пола,
## а наши дюны — сплошные склоны. Модификатор меряет высоту обеих стоп над
## ФАКТИЧЕСКИМ песком (вместе с промятостью следов) и просит игрока опустить
## (или поднять) корпус так, чтобы ОПОРНАЯ стопа стояла на дюне.
## Вторая нога на склоне остаётся выше/ниже — это и есть ходьба по барханам:
## тело прижимается к рельефу, а не шагает по невидимому полу.
##
## Смещение применяется к узлу модели из player._update_visual — кости
## не трогаем: анимация перезаписывает позы каждый кадр, а неизменяемые
## треки при импорте вырезаются, так что инкремент кости накоплялся бы.

const FOOT_L := &"Foot.L"
const FOOT_R := &"Foot.R"

const SMOOTH := 14.0 # скорость подстройки (1/с)
const DROP_MAX := 0.30 # насколько корпус может опуститься (глубокий шаг в ложбине)
const RISE_MAX := 0.10 # и подняться (пятка на гребне)


var player: Player

var _foot_l := -1
var _foot_r := -1
var _rest := 0.09 # высота кости стопы над песком в стойке (калибруется)
var _calibrated := false
var _off := 0.0


func setup(player_ref: Player) -> void:
	player = player_ref
	var skel := get_skeleton()
	if skel == null:
		return
	_foot_l = skel.find_bone(FOOT_L)
	_foot_r = skel.find_bone(FOOT_R)
	if _foot_l < 0 or _foot_r < 0:
		push_warning("FootPlant: кости стоп не найдены (%s/%s)" % [FOOT_L, FOOT_R])


func _process_modification() -> void:
	if player == null or _foot_l < 0:
		return
	var skel := get_skeleton()
	if skel == null:
		return
	var dt := get_process_delta_time()

	var gt: Transform3D = skel.global_transform
	var fl: Vector3 = gt * (skel.get_bone_global_pose(_foot_l).origin)
	var fr: Vector3 = gt * (skel.get_bone_global_pose(_foot_r).origin)

	var target := 0.0
	if not _calibrated:
		if not player.grounded:
			return
		# высота стопы над песком в спокойной стойке — по нижней стопе
		var hl: float = player.terrain.ground_height(fl.x, fl.z)
		var hr: float = player.terrain.ground_height(fr.x, fr.z)
		_rest = minf(fl.y - hl, fr.y - hr)
		_calibrated = true
	else:
		# погружение путника: стопы уходят в песок на ту же глубину
		var sink := player.foot_sink_m()
		var el: float = fl.y - (player.terrain.ground_height(fl.x, fl.z) + _rest - sink)
		var er: float = fr.y - (player.terrain.ground_height(fr.x, fr.z) + _rest - sink)
		# опорная стопа — та, что ближе к песку; её и сажаем
		var err := minf(el, er)
		if player.grounded:
			target = clampf(-err, -RISE_MAX, DROP_MAX)

	_off = lerpf(_off, target, 1.0 - exp(-SMOOTH * dt))
	player.note_plant_offset(_off)
