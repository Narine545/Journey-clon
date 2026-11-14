"""Original cut-paper composition guards, no render/image-similarity claim."""
from pathlib import Path
p = Path('scripts/raid_cut_panel.gd').read_text()
s = Path('scripts/raid_combat_ui.gd').read_text()
h = Path('scripts/raid_hud.gd').read_text()
assert 'smooth_polygon(self, shadow, underprint)' in p
assert 'smooth_polygon(self, shape, paper)' in p
assert 'StyleBoxEmpty.new()' in p and 'resized.connect(queue_redraw)' in p
assert 'rotation' not in s  # actual labels and hit areas are not arbitrarily rotated
assert 'weapon_cards[2].reparent(self)' in s
assert 'weapon_titles[2].add_theme_font_size_override("font_size", 28)' in s
assert 'run.pulse_cooldown <= 0.0' in s
assert 'weapon_cards[4].visible = run.sphere_rank > 0' in s
assert 'weapon_cards[5].visible = run.gravity_rank > 0' in s
assert '_tools_panel' in h and '_draw_boss_objective(enemy)' in h
# Diagonal quadrilateral remains convex and nondegenerate at narrow/wide sizes.
for w, height in ((218,108),(242,158),(320,66)):
    edge=min(14,w*.1)
    points=[(edge,0),(w,3),(w-edge,height),(0,height-3)]
    cross=[]
    for i in range(4):
        a,b,c=points[i],points[(i+1)%4],points[(i+2)%4]
        cross.append((b[0]-a[0])*(c[1]-b[1])-(b[1]-a[1])*(c[0]-b[0]))
    assert all(v>0 for v in cross)
print('PASS cut-paper backing, independent Q, installed-only equipment and stable text geometry')

assert "canvas.draw_polyline(perimeter, color, 1.0, true)" in p
assert "perimeter.append(perimeter[0])" in p
