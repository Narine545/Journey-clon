#!/usr/bin/env python3
"""Create a lightly refined texture atlas from NZ:P's original CC BY-SA image.

Requires Pillow. Keep UV layout unchanged; this is not a replacement for a
hand-painted high-resolution material. See concepts/nzp_springfield/README.md.
"""
from pathlib import Path
import math
import random
from PIL import Image, ImageFile, ImageFilter

root = Path(__file__).resolve().parents[1]
source = root / 'concepts/nzp_springfield/source/texture_0.png'
target = root / 'assets/weapons/nzp_springfield_texture.png'
# The upstream file has a bad iCCP checksum; its image data is intact and
# Blender decodes it. Do not use this flag on arbitrary untrusted files.
ImageFile.LOAD_TRUNCATED_IMAGES = True
with Image.open(source) as original:
    assert original.size == (128, 128)
    image = original.convert('RGB').resize((512, 512), Image.Resampling.LANCZOS)
image = image.filter(ImageFilter.UnsharpMask(radius=1.0, percent=70, threshold=4))
pix = image.load()
rng = random.Random(21567)
for y in range(256, 512):
    for x in range(512):
        r, g, b = pix[x, y]
        # The gun's brown wooden UV islands are in the lower half of the atlas.
        # Avoid altering hands/sleeves and neighbouring dark metal/empty UVs.
        if r > 28 and r > 1.14 * g and r > 1.14 * b and g > 10:
            grain = 2.0 * math.sin((y - x * 0.20) * 0.32 + math.sin(x * 0.025))
            noise = rng.uniform(-1.2, 1.2)
            pix[x, y] = tuple(max(0, min(255, round(c + (grain + noise) * w)))
                              for c, w in zip((r, g, b), (1.0, 0.72, 0.45)))
target.parent.mkdir(parents=True, exist_ok=True)
image.save(target, optimize=True)
print('Saved refined atlas:', target, image.size)
