"""`:=` от объекта без типа — ошибка компиляции, из-за которой не открывается проект.

Godot 4.7 не выводит тип у члена нетипизированной переменной: `var tp := water.level_y`
даёт «Cannot infer the type of "tp" variable», скрипт не собирается, зависимые
сцены падают — редактор уходит в recovery mode. Такие строки ловим до CI.
"""
import re
from pathlib import Path

files = list(Path('scripts').rglob('*.gd')) + list(Path('godot_fish').glob('*.gd'))

# `var name` без типа и без значения -> Variant (у членов нет выводимого типа).
UNTYPED = re.compile(r'^\s*var\s+(\w+)\s*(?:#[^\n]*)?$', re.M)
INFERRED = re.compile(r'\s*var\s+(\w+)\s*:=\s*(.+)')

problems = []
for path in files:
    source = path.read_text(encoding='utf-8', errors='ignore')
    untyped = {m.group(1) for m in UNTYPED.finditer(source)}
    if not untyped:
        continue
    for number, line in enumerate(source.splitlines(), 1):
        match = INFERRED.match(line)
        if not match:
            continue
        for name in untyped:
            if re.search(r'\b' + name + r'\s*\.', match.group(2)):
                problems.append(f'{path}:{number}: {line.strip()}  (без типа: {name})')

assert not problems, 'вывод типа из нетипизированного объекта:\n' + '\n'.join(problems)

# Модуль рыбалки обязан объявлять типы там, где тип неизвестен.
rod = Path('godot_fish/rod_cast.gd').read_text()
assert 'var tp: float = (water.level_y - origin.y) / fdir.y' in rod
assert 'var horiz: float = tp * sqrt' in rod
assert 'var w2: Vector2 = game.wind_dir()' in rod
print('check_godot_fish_types: ok')
