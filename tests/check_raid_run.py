"""Static integration guards and numerical policy mirrors; NOT a Godot run."""
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
run = (ROOT / "scripts/raid_run.gd").read_text()
hud = (ROOT / "scripts/raid_hud.gd").read_text()
main = (ROOT / "scripts/boat_main.gd").read_text()
boat = (ROOT / "scripts/boat_vessel.gd").read_text()
smoke = (ROOT / "scripts/boat_smoke.gd").read_text()

# Node3D already owns basis; local declarations must not shadow it.
assert "var basis" not in run
assert "var enemy_basis :=" in run
assert "Transform3D(enemy_basis," in run

assert "const ENEMY_CAP := 80" in run
assert "const SHOT_CAP := 160" in run
assert "const DURATION := 300.0" in run
assert "if shots.size() < SHOT_CAP:" in run
assert "if enemies.size() >= ENEMY_CAP:" in run
assert "MultiMesh.new()" in run and "visible_instance_count" in run
assert "grid.clear()" in run and "func _rebuild_grid()" in run
assert "CELL := 8.0" in run
assert 'shot["hostile"]' in run and "previous.distance_to(next) / 0.45" in run
assert "main.harbor.blocks_hull(at," in run
assert "water_depth(center.x, center.y) >= 2.5" in run
assert 'reef["radius"]' in run
assert "main.boat.apply_hull_damage(amount)" in run
assert "else 15.0" in boat and "maxf(minimum, hull_hp - maxf(0.0, amount))" in boat
assert "_hurt_timer = 0.65" in run
assert "main.boat._trailer" in run and "global_rotation.y" in run
assert "choices.append(available.pop_at(index))" in run
assert "xp -= xp_needed" in run and "if xp >= xp_needed:" in run
assert "_saved_hp = main.boat.hull_hp" in run
assert "main.boat.hull_hp = _saved_hp" in run
assert "main.debug_panel_visible = _saved_debug" in run
assert "boss_spawned = _spawn(3)" in run and "enemies.remove_at(0)" in run
assert "elapsed >= 240.0" in run and "elapsed >= 225.0" in hud
assert "distance_to(enemies[index]" in run and "> 100.0" in run
assert "1.0 if modal() or main.inspection_active()" in " ".join(run.split())
assert "_physics_process" in run and "state != State.RUNNING or main.inspection_active()" in run
assert "raid.setup(self)" in main and "func gameplay_paused()" in main
assert "raid.modal() or inspection_active()" in main
physics = boat.split("func _physics_process", 1)[1].split("func _separate_trailer_from", 1)[0]
assert physics.index("main.gameplay_paused()") < physics.index("_anim_time += delta")
assert "not (raid != null and raid.engaged())" in main
assert "KEY_1, KEY_2, KEY_3" in main  # no pigment charges hidden behind raid's HUD
assert "KEY_Q" in run and "KEY_ESCAPE" in run
assert "_check_raid()" in smoke and "run._move_shots(0.5)" in smoke
assert "run.restart" in hud and "run.leave" in hud
for forbidden in ("OmniLight3D", "SpotLight3D", "SubViewport", "RigidBody3D", "NavigationAgent3D"):
    assert forbidden not in run + hud, forbidden
assert "raw[" not in run and "refined[" not in run


def segment_distance(p, a, b):
    ab = (b[0] - a[0], b[1] - a[1])
    length2 = ab[0] ** 2 + ab[1] ** 2
    t = max(0, min(1, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / max(length2, 0.000001)))
    return math.dist(p, (a[0] + t * ab[0], a[1] + t * ab[1]))


assert segment_distance((5, 3), (0, 0), (10, 0)) == 3
assert segment_distance((-2, 0), (0, 0), (10, 0)) == 2
assert segment_distance((2, 0), (0, 0), (0, 0)) == 2
rng = random.Random(127)
for _ in range(1000):
    a, b, p = [tuple(rng.uniform(-100, 100) for _ in range(2)) for _ in range(3)]
    d = segment_distance(p, a, b)
    assert math.isclose(d, segment_distance(p, b, a), abs_tol=1e-9)
    assert 0 <= d <= min(math.dist(p, a), math.dist(p, b)) + 1e-9

# Grid broadphase must include every sphere that a swept shot could intersect.
for _ in range(2000):
    a, b = [tuple(rng.uniform(-60, 60) for _ in range(2)) for _ in range(2)]
    center = tuple((a[i] + b[i]) * 0.5 for i in range(2))
    radius = math.dist(a, b) * 0.5 + 4.0
    p = tuple(rng.uniform(-60, 60) for _ in range(2))
    if segment_distance(p, a, b) <= 3.7:
        cell = tuple(math.floor(v / 8) for v in p)
        lo = tuple(math.floor((v - radius) / 8) for v in center)
        hi = tuple(math.floor((v + radius) / 8) for v in center)
        assert all(lo[i] <= cell[i] <= hi[i] for i in range(2))

# Heading sectors rotate with the vessel, not the camera.
for step in range(360):
    yaw = math.radians(step)
    fwd = (-math.sin(yaw), -math.cos(yaw))
    side = (-fwd[1], fwd[0])
    assert math.isclose(fwd[0] ** 2 + fwd[1] ** 2, 1)
    assert abs(sum(a * b for a, b in zip(fwd, side))) < 1e-12
    assert sum(a * b for a, b in zip(fwd, side)) < 0.65
    assert sum(v * v for v in fwd) > 0.65

# Finite short substeps retain hits even at low render FPS/large test dt.
for dt in (1 / 120, 1 / 60, 1 / 20, 0.5):
    length = 38 * dt
    steps = max(1, math.ceil(length / 0.45))
    assert length / steps <= 0.45
    for target in [length * 0.2, length * 0.5, length * 0.9]:
        assert any(abs(length * step / steps - target) < 1.1 + 0.3 for step in range(1, steps + 1))

# Unique upgrade choices, including saturated build cases.
for pellets in range(1, 6):
    for reload in (1, 0.5, 0.35):
        pool = [0, 1, 2, 3, 4]
        if pellets >= 5:
            pool.remove(2)
        if reload <= 0.38:
            pool.remove(1)
        options = rng.sample(pool, 3)
        assert len(set(options)) == 3
        assert 2 not in options or pellets < 5
        assert 1 not in options or reload > 0.38

print("PASS: raid wiring, caps, geometry, grid coverage, sectors, substeps and upgrade policy (not engine/runtime)")
