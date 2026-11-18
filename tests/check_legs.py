"""Ходячие ноги: бонус рейда, шаг по воде, пинки и плашка в HUD."""
from pathlib import Path

run = Path('scripts/raid_run.gd').read_text()
legs = Path('scripts/raid_legs.gd').read_text()
vessel = Path('scripts/boat_vessel.gd').read_text()
hud = Path('scripts/ui/screens/hud_tide.gd').read_text()
ui = Path('scripts/ui/tide_ui.gd').read_text()
stats = Path('scripts/raid_stats.gd').read_text()

# Улучшение есть в общем списке и в пуле выбора, с превью и выбором.
assert '["Ходячие ноги", "На время вырастают ноги: X — шаг по воде, пинки с борта"]' in run
assert 'available.append(19)' in run
assert 'legs_rank = mini(LEGS_RANK_MAX, legs_rank + 1)' in run
assert 'preview = (' in run and 'Шаг: %.0f → %.0f с' in run
# Бонус временный: таймер, отдых, повторный запуск по X.
assert 'const LEGS_TIME := 20.0' in run
assert 'const LEGS_COOLDOWN := 34.0' in run
assert 'const LEGS_SPEED := 1.25' in run
assert 'elif event.physical_keycode == KEY_X:' in run
assert 'func legs_active() -> bool:' in run
assert 'func start_legs() -> void:' in run
assert '_legs_kick()' in run
assert 'RaidStats.Channel.LEGS' in run
assert 'GRAVITY, LEGS }' in stats
# На ногах судно идёт по поверхности: меньшая требуемая глубина.
assert 'return 0.55 if raid_legs_active() else 1.7' in vessel
assert 'var legs_lift := 4.2 if raid_legs_active() else 0.0' in vessel
# Ноги живут в мире: IK, шаги с опорой, пинок.
assert 'class_name RaidLegs' in legs
assert 'func _knee(hip: Vector3, foot: Vector3, pole: Vector3) -> Vector3:' in legs
assert 'const THIGH := 3.4' in legs and 'const SHIN := 3.5' in legs
assert 'func kick(side: float) -> void:' in legs
assert 'main.water.field.splash(Vector2(at.x, at.z), 0.85)' in legs
# Плашка бонуса в боевом HUD.
assert 'НОГИ · ШАГ · %d С' in ui and 'НОГИ ГОТОВЫ · X' in ui
assert 'const LEGS_RECT := Rect2(600, 892, 380, 60)' in hud

# Появление без резины: ступни ставятся под бёдра, нога не длиннее себя.
assert 'func _seed_feet() -> void:' in legs
assert 'if value and not _want:' in legs
assert 'var foot := _reach(hip, to_local(foot_world))' in legs
assert 'var limit := THIGH + SHIN - 0.05' in legs
