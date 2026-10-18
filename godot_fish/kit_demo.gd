class_name FishKitDemo
extends Node3D
## Автономная демо-сцена «Кит песчаных рыб»: 7 видов на песчаном море,
## собранные кодом. Проверка перед интеграцией: если эта сцена работает,
## FishKit совместим с проектом (sand_sea_sdf + fish_kit_map.gdshaderinc).
##
## Запуск: сцена с одной нодой Node3D + этот скрипт, затем F6.
##
## Управление:
##   1..7    — заселить слот видом (0..2 заняты — идёт плавный морф)
##   ← →     — сменить вид всем рыбам по кругу
##   S       — напугать (у каждого вида своя реакция)
##   J       — форс-прыжок
##   X       — X-ray: скелет-цепочка просвечивает сквозь тело
##   WASD / Q E — полёт камеры, Shift — быстрее, мышь — обзор (клик = захват)

const CAM_POS := Vector3(0.0, 2.4, 12.0)

var kit: FishKit
var cam: Camera3D

var _keys := {}
var _speed := 6.0
var _yaw := 0.35
var _pitch := -0.10
var _mouse_captured := false


## Утка-заглушка автозагрузки Game (те же поля, что читает FishKit).
class DemoGame:
        var sun_dir := Vector3(0.10, 0.26, -0.96).normalized()
        var FOG_DISTANCE := 340.0
        var wind_strength := 1.0
        var _wind := Vector2(0.32, -0.95).normalized()

        func wind_dir() -> Vector2:
                return _wind


func _ready() -> void:
        var game := DemoGame.new()
        _build_sky(game.sun_dir)

        kit = FishKit.new()
        add_child(kit)
        kit.setup(game, 0.0, null)
        kit.add_fish(0, Vector2(3.5, 4.5)) # странник — у камеры
        kit.add_fish(2, Vector2(-4.0, -2.0)) # фонарник — в «вуали»
        # третий слот свободен: клавиши 1..7 заселяют его выбранным видом
        kit.set_showcase(0, true) # сразу видно: странник кружит над песком

        _build_camera()


func _build_sky(sun_dir: Vector3) -> void:
        var sun := DirectionalLight3D.new()
        sun.look_at_from_position(Vector3.ZERO, Vector3.ZERO - sun_dir)
        sun.light_energy = 1.2
        sun.light_color = Color(1.0, 0.85, 0.66)
        add_child(sun)

        var env := Environment.new()
        var sky := Sky.new()
        var mat := ProceduralSkyMaterial.new()
        mat.sky_top_color = Color(0.28, 0.24, 0.43)
        mat.sky_horizon_color = Color(0.96, 0.66, 0.55)
        mat.ground_bottom_color = Color(0.40, 0.32, 0.52)
        mat.ground_horizon_color = Color(0.96, 0.66, 0.55)
        sky.sky_material = mat
        env.background_mode = Environment.BG_SKY
        env.sky = sky
        env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
        var we := WorldEnvironment.new()
        we.environment = env
        add_child(we)


func _build_camera() -> void:
        cam = Camera3D.new()
        cam.position = CAM_POS
        cam.fov = 75.0
        cam.near = 0.05
        cam.far = 1200.0
        add_child(cam)
        cam.make_current()


func _input(event: InputEvent) -> void:
        if event is InputEventMouseMotion and _mouse_captured:
                _yaw = wrapf(_yaw - event.relative.x * 0.0022, -PI, PI)
                _pitch = clampf(_pitch - event.relative.y * 0.0022, -1.2, 0.6)
        elif event is InputEventMouseButton and event.pressed \
                        and event.button_index == MOUSE_BUTTON_LEFT and not _mouse_captured:
                _mouse_captured = true
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        elif event is InputEventKey:
                var k := event as InputEventKey
                _keys[k.keycode] = k.pressed
                if not k.pressed:
                        return
                match k.keycode:
                        KEY_ESCAPE:
                                _mouse_captured = false
                                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
                        KEY_LEFT:
                                _cycle(-1)
                        KEY_RIGHT:
                                _cycle(1)
                        KEY_S:
                                kit.startle()
                        KEY_J:
                                kit.force_jump()
                        KEY_X:
                                kit.debug_xray = not kit.debug_xray
                        KEY_V:
                                var sv := not kit.is_showcase(0)
                                for i in range(FishKit.MAX_FISH):
                                        kit.set_showcase(i, sv)
                        KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
                                var id := k.keycode - KEY_1
                                var added := -1
                                if kit.has_free_slot():
                                        added = kit.add_fish(id)
                                else:
                                        kit.set_species(2, id) # третий слот — витрина видов
                                        added = 2
                                if added >= 0:
                                        kit.set_showcase(added, true)


func _cycle(dir: int) -> void:
        # сменить вид всем активным рыбам по кругу паспортов + поднять в показ
        for i in range(FishKit.MAX_FISH):
                kit.set_species(i, wrapi(kit.species_of(i) + dir, 0, FishKit.SPECIES.size()))
                kit.set_showcase(i, true)


func _process(delta: float) -> void:
        if cam == null:
                return
        cam.rotation = Vector3(_pitch, _yaw, 0.0)
        var f := -cam.global_transform.basis.z
        var r := cam.global_transform.basis.x
        var move := Vector3.ZERO
        if _keys.get(KEY_W, false):
                move += f
        if _keys.get(KEY_S, false):
                move -= f
        if _keys.get(KEY_D, false):
                move += r
        if _keys.get(KEY_A, false):
                move -= r
        if _keys.get(KEY_E, false):
                move += Vector3.UP
        if _keys.get(KEY_Q, false):
                move -= Vector3.UP
        if move != Vector3.ZERO:
                var spd := _speed * (2.5 if _keys.get(KEY_SHIFT, false) else 1.0)
                cam.global_position += move.normalized() * spd * delta
        cam.global_position.y = maxf(cam.global_position.y, 0.6) # не нырять под море
