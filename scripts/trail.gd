class_name Trail
extends SubViewport
## Карта следов: позиции путника «приминают» песок, след медленно
## затягивается (~минуты). Каждый кадр карта перерисовывается целиком:
## чёрный фон + аддитивные штампы, альфа каждого — его возраст.
## Экспоненциальное затухание pow(0.5, age/45с) считается точно в скрипте,
## поэтому нет проблемы 8-битного буфера (multiply-затухание застревает).
## Шейдер песка читает текстуру: рябь приглушена, цвет чуть продавлен.


const MAP := 1024
const X0 := -208.0 # покрываемая область мира (метры)
const Z0 := -468.0
const WORLD_W := 416.0
const WORLD_H := 520.0
const HALF_LIFE := 45.0 # секунд до половины «затягивания» песком
const LIVE_HALF_LIVES := 5.0 # после — штамп выбрасывается (альфа < 3%)

var stamp_count := 0 # диагностика / smoke-тест

var _bg: BgLayer
var _layer: StampLayer
var _stamps: Array[Stamp] = []
var _now := 0.0


func setup() -> void:
	size = Vector2i(MAP, MAP)
	disable_3d = true
	transparent_bg = false
	handle_input_locally = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS

	_bg = BgLayer.new()
	add_child(_bg)
	_bg.queue_redraw()

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_layer = StampLayer.new()
	_layer.material = add_mat
	_layer.tex = ProcTextures.radial(48, 1.7)
	_layer.stamps = _stamps
	add_child(_layer)


func _process(delta: float) -> void:
	_now += delta
	# штампы лежат по времени рождения: состарившиеся — в начале
	var horizon := _now - HALF_LIFE * LIVE_HALF_LIVES
	while not _stamps.is_empty() and _stamps[0].birth < horizon:
		_stamps.pop_front()
	_layer.now = _now
	_layer.half_life = HALF_LIFE
	_layer.queue_redraw()


## Штамп следа в мировых координатах.
func stamp(world_x: float, world_z: float, radius_m: float, intensity: float) -> void:
	var px := (world_x - X0) / WORLD_W * float(MAP)
	var py := (world_z - Z0) / WORLD_H * float(MAP)
	# меньше 2 пикселей не различить — но и раздувать сильно нельзя
	var pr := maxf(radius_m / WORLD_W * float(MAP), 2.0)
	_stamps.push_back(Stamp.new(px, py, pr, clampf(intensity, 0.0, 1.0), _now))
	stamp_count += 1


class Stamp:
	extends RefCounted
	## Один отпечаток: позиция в пикселях карты, радиус, сила, момент появления.

	var x := 0.0
	var y := 0.0
	var r := 1.0
	var amp := 1.0
	var birth := 0.0


	func _init(px: float, py: float, pr: float, pamp: float, pbirth: float) -> void:
		x = px
		y = py
		r = pr
		amp = pamp
		birth = pbirth


class BgLayer:
	extends Node2D
	## Гарантированно чёрный фон карты (каким бы ни был clear color вьюпорта).

	func _draw() -> void:
		draw_rect(Rect2(0.0, 0.0, Trail.MAP, Trail.MAP), Color(0.0, 0.0, 0.0, 1.0))


class StampLayer:
	extends Node2D
	## Рисует все живые штампы; альфа каждого гаснет с возрастом.

	var tex: ImageTexture
	var stamps: Array[Trail.Stamp]
	var now := 0.0
	var half_life := 45.0

	func _draw() -> void:
		for s in stamps:
			var a: float = s.amp * pow(0.5, (now - s.birth) / half_life)
			if a < 0.02:
				continue
			draw_texture_rect(
				tex,
				Rect2(s.x - s.r, s.y - s.r, s.r * 2.0, s.r * 2.0),
				false,
				Color(1.0, 1.0, 1.0, a)
			)
