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
# --- тело рисует модуль рыбалки, а не собственные примитивы
assert 'SandFish.new()' in whales
assert '_fish.set_external(true)' in whales
assert 'res://shaders/sand_sea_sdf.gdshader' in fish
for banned in ('SphereMesh', 'BoxMesh', 'CapsuleMesh', 'CylinderMesh'):
    assert banned not in whales, banned
assert 'const BODY_LEN := 6.0' in whales
assert 'const BODY_SIZE := BODY_LEN / SDF_LEN' in whales

# --- кожа и свечение считаются в шейдере, в системе тела
assert 'uniform float u_fish_pitch[7];' in shader
assert 'uniform float u_glow = 0.0;' in shader
assert 'uniform float u_veil_dark = 0.12;' in shader
assert 'float back = smoothstep(-0.45, 0.55, upw);' in shader       # контражур
assert 'float speck = step(0.87, hash12(' in shader                 # крап
assert 'skin *= 1.0 - 0.13 * (0.5 + 0.5 * sin(along * 22.0))' in shader  # борозды
assert 'col += albedo * u_glow' in shader                            # биолюминесценция
assert 'vec3 up = normalize(cross(side, dir));' in shader            # тангаж
assert 'fish_sdf(p, C, s, u_fish_state[i].w, u_fish_pitch[i],' in shader
assert 'out_col = scene_col * (1.0 - u_veil_dark * m)' in shader     # тень под водой

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
# Вне кадра полноэкранный проход не считается вообще.
assert '_fish.set_sdf_enabled(_any_in_view())' in whales
assert 'main.camera.is_position_in_frustum(probe)' in whales

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
assert 'кит не лезет под корпус' in smoke
print('check_sea_whales: ok')
