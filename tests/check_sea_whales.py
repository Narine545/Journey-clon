"""Светящиеся киты: ночная стая, самосвечение без лишних источников света."""
from pathlib import Path

whales = Path('scripts/sea_whales.gd').read_text()
main = Path('scripts/boat_main.gd').read_text()

assert 'class_name SeaWhales' in whales
assert 'const POD_SIZE := 3' in whales
assert 'const GLOW := Color(0.36, 0.96, 0.92)' in whales

# Только ночью, с гистерезисом: днём стаи нет совсем.
assert 'const NIGHT_IN := 0.42' in whales and 'const NIGHT_OUT := 0.26' in whales
assert 'var want := night01 > NIGHT_IN if not active else night01 > NIGHT_OUT' in whales
assert 'visible = _shown > 0.01' in whales

# Стая живёт вокруг судна и не уходит за свой радиус.
assert 'const SWIM_RADIUS := 120.0' in whales
assert 'if offset.length() > SWIM_RADIUS:' in whales
assert 'at += heading * float(whale["speed"]) * delta' in whales

# Свет — эмиссия и аддитивные блики: ни одного источника света на кита.
assert 'glow_mat.emission_enabled = true' in whales
assert 'glow_mat.emission_energy_multiplier = 3.4' in whales
assert 'halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD' in whales
assert 'pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD' in whales
assert 'OmniLight3D' not in whales and 'SpotLight3D' not in whales
# Материалы создаются один раз при сборке, а не каждый кадр.
assert whales.count('StandardMaterial3D.new()') == 4
# Светится сам зверь: гребень по спине + крупные огни на боках.
assert 'spine.material_override = glow_mat' in whales
assert 'spine.scale = Vector3(BODY_LEN * 0.16, BODY_LEN * 0.12, BODY_LEN * 0.78)' in whales
# Киты — мировые координаты, узел стаи только контейнер.
assert 'root.top_level = true' in whales
# След на воде берётся из готового поля колец, а не из новых частиц.
assert 'main.water.field.splash(at - whale["dir"] * BODY_LEN * 0.5, 0.35)' in whales

# Встроено в цикл мира.
assert 'var sea_whales: SeaWhales' in main
assert 'sea_whales.setup(self)' in main
assert 'sea_whales.advance(delta, night01)' in main
print('OK: киты выходят ночью, светятся сами и не стоят в кадре.')
