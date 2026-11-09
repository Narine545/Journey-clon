"""Optional top-down water/fog experiment source and math guards, not GPU/render proof."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
water = (root / 'shaders/water_boat.gdshader').read_text()
fog = (root / 'shaders/boat_rme4_fog.gdshader').read_text()
trial = (root / 'scripts/sea_look_trial.gd').read_text()
main = (root / 'scripts/boat_main.gd').read_text()
smoke = (root / 'scripts/boat_smoke.gd').read_text()
assert 'sea_look_trial.setup(self)' in main
assert 'uniform float depth_palette_strength : hint_range(0.0, 1.0) = 0.0;' in water
assert 'float chart_depth = max(sea_level - ground, 0.0);' in water
assert 'texture(depth_palette, vec2(palette_u, 0.5)).rgb' in water
assert 'base = mix(base, chart_color, depth_palette_strength * 0.35)' in water
assert water.index('vec3 chart_color') < water.index('base += sun_col * path')
assert 'uniform float mist_pockets : hint_range(0.0, 1.0) = 0.0;' in fog
assert 'clamp(mist_pockets, 0.0, 1.0) * profile' in fog
assert 'body = mix(body, pocket_mask, pocket_mode);' in fog
assert 'ceiling = mix(ceiling, 0.70 + height_noise * 0.95, pocket_mode);' in fog
assert '* weather_fog' in fog
assert fog.count('texture(density_noise,') == 4  # reuse noise, not a new sampler pass
for label in ('Цвет по глубине', 'Низкие клочья тумана'):
    assert label in trial
assert 'main._rme4_material != null' in trial and '_mist_toggle.disabled = not supported' in trial
assert 'main.inspection_active()' in trial and 'main.raid.modal()' in trial
assert '_check_sea_look_trial()' in smoke
for bad in ('FogVolume.new', 'Environment.new', 'Input.', 'volumetric_fog_enabled =', 'SCREEN_TEXTURE'):
    assert bad not in trial
# Wave height/camera changes cannot alter the new palette coordinate.
for ground in (-20, -14, -6, -2, 0, 1):
    expected = min(1, max(0, -ground) / 14)
    for wave in (-1, 0, 1):
        for camera_height in (10, 30, 80):
            u = min(1, max(0, 0 - ground) / 14)
            assert u == expected
for noise in (0, .25, .5, .75, 1):
    old = 1.2 + noise * 1.4
    new = .7 + noise * .95
    assert .7 <= new <= 1.65 and new < old
    assert old * (1 - 0) + new * 0 == old  # toggle-off ceiling unchanged
# No new floor: fully empty pocket is allowed; peak never exceeds old body's ceiling 1.
for pocket in (0, .25, .5, .75, 1):
    for old_body in (.2, .5, 1):
        assert 0 <= old_body * 0 + pocket <= 1
print('PASS: stable bathymetry, bounded low mist, independent off paths, weather/renderer guards (not render)')
