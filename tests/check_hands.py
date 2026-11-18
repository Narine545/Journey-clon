"""Хватающие руки: пассивный бонус рейда, автохватка, бросок во второго и HUD."""
from pathlib import Path

run = Path('scripts/raid_run.gd').read_text()
hands = Path('scripts/raid_hands.gd').read_text()
motion = Path('scripts/raid_motion.gd').read_text()
stats = Path('scripts/raid_stats.gd').read_text()
hud = Path('scripts/ui/screens/hud_tide.gd').read_text()
ui = Path('scripts/ui/tide_ui.gd').read_text()

# Улучшение в общем списке и в пуле выбора, с превью.
assert '["Хватающие руки", "Автоматически хватают врага и швыряют его в другого"]' in run
assert 'available.append(20)' in run
assert 'hands_rank = mini(HANDS_RANK_MAX, hands_rank + 1)' in run
assert '"Хватка: %.0f → %.0f урона\\nПауза: %.1f → %.1f с"' in run
assert 'const HANDS_RANK_MAX := 3' in run
assert 'const HANDS_REACH := 13.0' in run

# Хватка автоматическая: свой шаг рейда, без нажатия клавиши.
assert 'func _step_hands(delta: float) -> void:' in run
assert '_step_hands(delta)' in run
assert 'func _hands_grab() -> bool:' in run
assert 'func hands_hit(' in run
assert 'RaidStats.Channel.HANDS' in run
assert 'LEGS, HANDS }' in stats
# Бросок — не обычный толчок: врага уносит в конкретную точку.
assert 'static func throw_at(' in motion
assert 'enemy["thrown"] = 0.6' in motion
assert 'RaidMotion.throw_at(victim, from_at, landing, HANDS_THROW)' in run
# Второй враг получает удар от летящего тела.
assert 'RaidMotion.kick(partner, at, HANDS_THROW * 0.45, 6.0)' in run
assert 'main.announce("СХВАТИЛ И ШВЫРНУЛ.")' in run

# Руки живут на корпусе: две руки, IK, пальцы сжимаются, урон по моменту хватки.
assert 'class_name RaidHands' in hands
assert 'const SIDES := [-1.0, 1.0]' in hands
assert 'func grab(side: float, at_world: Vector3, on_hit: Callable) -> void:' in hands
assert 'func busy() -> bool:' in hands
assert 'if not bool(arm.get("fired", false)) and k >= 0.40:' in hands
assert 'var curl := lerpf(0.12, 1.30, grip)' in hands
assert 'scale = Vector3(0.55 + 0.45 * grow, grow, 0.55 + 0.45 * grow)' in hands

# Плашка в боевом HUD: строка над ногами, без наложения.
assert 'const HANDS_RECT := Rect2(600, 828, 380, 60)' in hud
assert '_hands_plate.visible = not hands.is_empty()' in hud
assert 'РУКИ · ХВАТКА' in ui and 'РУКИ ГОТОВЫ' in ui
