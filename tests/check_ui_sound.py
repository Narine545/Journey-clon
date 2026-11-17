"""Отклик интерфейса: один тихий кап на нажатие, общий для всех экранов."""
from pathlib import Path

project = Path('project.godot').read_text()
sound = Path('scripts/ui/tide_ui_sound.gd').read_text()
button = Path('scripts/ui/kit/tide_button.gd').read_text()
assert 'UiSound="*res://scripts/ui/tide_ui_sound.gd"' in project
assert 'func tap() -> void:' in sound
assert 'const VOLUME_DB := -15.0' in sound
# Кнопка отзывается один раз, на отпускании, и не отзывается, если её скрыли.
assert 'UiSound.tap()' in button
assert button.index('UiSound.tap()') > button.index('func _on_up() -> void:')
assert button.count('UiSound.tap()') == 1
