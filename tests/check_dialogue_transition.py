"""Luminance mask and lifecycle wiring; visual timing is covered by village audit."""
from pathlib import Path
import struct, zlib

shader = Path('shaders/dialogue_luminance_transition.gdshader').read_text()
interaction = Path('scripts/village_interaction.gd').read_text()
assert 'dot(mask_color, vec3(0.2126, 0.7152, 0.0722))' in shader
assert 'mix(-0.1, 1.1' in shader and 'smoothstep' in shader
assert 'godotshaders.com/shader/luminance-mask-transition/' in shader
assert '_transition_midpoint' in interaction and '_transition_finish' in interaction
assert 'main.village_panel_open = true' in interaction and '_cancel_dialog()' in interaction
assert '_start_story_entrance()' in interaction
assert '_prepare_story_entrance()' in interaction
assert 'hint_screen_texture' in shader and 'texture(old_frame' in shader
assert 'get_viewport().get_texture().get_image()' in interaction
assert 'rotate_point(old_p' in shader
assert 'ink.rgb' not in shader
assert 'mask_style == 1' in shader and 'mask_style == 2' in shader
assert 'TRANSITION_STYLE_COUNT := 3' in interaction
assert '_transition_midpoint_done' in interaction
# Image is authored in-repo, grayscale PNG with a genuine range of luminance.
data = Path('assets/ui/dialogue_transition_mask.png').read_bytes()
assert data.startswith(b'\x89PNG\r\n\x1a\n')
pos = 8
compressed = b''
while pos < len(data):
    size = struct.unpack('!I', data[pos:pos+4])[0]
    kind = data[pos+4:pos+8]
    if kind == b'IDAT': compressed += data[pos+8:pos+8+size]
    pos += 12 + size
raw = zlib.decompress(compressed)
values = [v for i, v in enumerate(raw) if i % 513]
assert min(values) < 20 and max(values) > 220
print('check_dialogue_transition: ok')
