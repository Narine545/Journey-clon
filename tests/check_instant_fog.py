"""Instant preview bypasses weather delay without modifying the weather simulation."""
from pathlib import Path
main = Path('scripts/boat_main.gd').read_text()
ui = Path('scripts/sea_look_trial.gd').read_text()
body = main.split('func _apply_atmosphere(', 1)[1].split('\nfunc ', 1)[0]
assert 'var debug_instant_fog := false' in main
assert 'var effective_fog := 1.0 if debug_instant_fog else weather.fog_amount' in body
assert 'weather.fog_amount' not in body.split('else weather.fog_amount', 1)[1]
assert '"weather_fog", effective_fog' in body
assert 'effective_fog, weather.cloud_amount' in body
assert 'weather.advance(delta, night01)' in main
assert 'Туман сразу' in ui
assert 'main._apply_atmosphere(main.night01)' in ui
assert 'main.weather.' not in ui
print('PASS instant fog preview, immediate apply and independent weather')
