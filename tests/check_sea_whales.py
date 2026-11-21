"""Киты: SDF-существо из модуля рыбалки + физика движения в воде.

Проверяем не «красиво ли», а из чего сделано поведение: тело — тот же
SDF-рендер, что у рыб (никаких мешей-примитивов), высота следует за зыбью
пружиной, тангаж уходит в шейдер, есть след в воде, объезд судна по
упреждению, отталкивание от мелководья и отладка.
"""
from pathlib import Path

whales = Path('scripts/sea_whales.gd').read_text()
fish = Path('scripts/sand_fish.gd').read_text()
boat = Path('scripts/boat_main.gd').read_text()
shots = Path('scripts/light_shots.gd').read_text()
smoke = Path('scripts/boat_smoke.gd').read_text()
shader = Path('shaders/sand_sea_sdf.gdshader').read_text()

assert 'class_name SeaWhales' in whales
# Тело — единый меш и обычный освещаемый PBR-материал.
assert 'res://assets/creatures/whale.obj' in whales
assert 'res://shaders/whale_body.gdshader' in whales
assert 'body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON' in whales
assert '_fish.fish_count = 0' in whales  # SDF используется только для брызг
assert '_fish.push_creature(w.slot' not in whales
assert 'const SURFACE_DEPTH := 0.32' in whales
assert 'body.global_basis = Basis(Vector3.UP, -w.heading) * Basis(Vector3.BACK, w.pitch)' in whales
body_shader = Path('shaders/whale_body.gdshader').read_text()
assert 'unshaded' not in body_shader
assert 'EMISSION = glow_color.rgb * glow_strength' in body_shader
assert 'VERTEX.y += sin(swim_phase' in body_shader
assert Path('assets/creatures/whale.obj').stat().st_size > 1000

# --- движение: пружина глубины, тангаж из вертикальной скорости, гребок с глайдом
assert 'const SPRING := 1.7' in whales
assert 'var damping := 2.0 * sqrt(SPRING)' in whales
assert 'w.vy += (SPRING * (target_y - w.y) - damping * w.vy) * delta' in whales
assert 'main.water.surface_height(w.pos.x, w.pos.z)' in whales
assert 'var pitch_want := clampf(atan2(w.vy, maxf(w.speed, 0.6)), -0.45, 0.45)' in whales
assert 'var glide := 0.40 + 0.60 * (0.5 + 0.5 * sin(' in whales      # планирование
assert 'ST_SURFACE' in whales and 'ST_DIVE' in whales and 'ST_DEEP' in whales
assert 'const TURN_RATE := 0.30' in whales

# --- взаимодействие с водой: кольца, след, брызги
assert 'main.water.field.wake(Vector2(w.pos.x, w.pos.z), strength)' in whales
assert '_fish.splash_burst(' in whales
assert 'func _blow(w: Whale) -> void:' in whales
# Вода смешивается с реальным телом по depth, а не рисует плоский силуэт.
for banned in ('whale_glow.gdshader', 'whale_shadow.gdshader', 'QuadMesh'):
    assert banned not in whales, banned
assert 'main.camera.is_position_in_frustum(probe)' in whales
assert 'material.set_shader_parameter("glow_strength", want_glow)' in whales

# --- объезд судна по упреждению и мелководье
assert 'const BOAT_LOOKAHEAD := 6.0' in whales
assert 'var t_close := 0.0' in whales and 'var miss := rel + vel * t_close' in whales
assert 'const BOAT_CLEARANCE := 12.0' in whales and 'const BOAT_PANIC := 7.0' in whales
assert 'const DEEP_WATER := 5.0' in whales
assert 'func _shore_push(w: Whale, pos2: Vector2) -> Vector2:' in whales
assert 'main.coast.water_depth(' in whales

# --- спавн: рандомно в море, но недалеко от острова и на глубине
assert 'var shore := main.coast.shore_x(z)' in whales
assert 'if main.coast.water_depth(x, z) < 6.0:' in whales
assert 'var x := shore - randf_range(45.0, 185.0)' in whales

# --- отладка, чтобы китов не приходилось искать
assert 'func debug_toggle() -> void:' in whales
assert 'func nearest_to(at: Vector3) -> int:' in whales
assert 'var debug_on := false' in whales
assert 'KEY_F9:' in boat and 'sea_whales.debug_toggle()' in boat
assert 'KEY_F10:' in boat and 'debug_warp_to_whale()' in boat
assert 'func debug_warp_to_whale() -> void:' in boat

# --- проводка в игре, в кадрах CI и в головном тесте
assert 'sea_whales.advance(delta, night01)' in boat
assert 'main.sea_whales.place_near(main._camera_focus, fwd.normalized())' in shots
assert '_check_sea_whales()' in smoke
assert 'кит не телепортируется' in smoke
assert 'каждый кит имеет настоящую освещаемую геометрию' in smoke
assert 'кит не лезет под корпус' in smoke
print('check_sea_whales: ok')

# Параметры не затеняют встроенное свойство Node.owner.
assert 'func set_catch_visual(owner:' not in fish
assert 'func clear_catch_visual(owner:' not in fish

# Отдельный след на материале моря и подповерхностный свет от тела.
water_shader = Path('shaders/water_boat.gdshader').read_text()
assert 'uniform vec4 u_whale_trails[24]' in water_shader
assert 'a.z - b.z > 0.65' in water_shader  # не соединять след через нырок
assert 'u_whale_trails[wi * 12 + j]' in water_shader
assert 'whale_light' not in water_shader
assert 'scene_world = (INV_VIEW_MATRIX * vec4(vp.xyz, 1.0)).xyz' in water_shader
assert 'whale_transmission' in water_shader
assert 'EMISSION += foam_col * whale_foam' in water_shader
assert 'whale_shadow' not in water_shader
assert 'main.water.set_param("u_whale_trails", trails)' in whales
assert 'func _reset_trail(w: Whale)' in whales
assert 'elif w.surface_contact and depth_now > 0.7:' in whales
