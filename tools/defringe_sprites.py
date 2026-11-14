#!/usr/bin/env python3
"""Чистка ореола у вырезанных спрайтов (assets/story/*.webp).

После удаления белого фона по краю силуэта остаются светлые полупрозрачные
пиксели. Скрипт «заливает» их снаружи: от прозрачной области внутрь, но только
по бледным (почти белым) или полупрозрачным пикселям и не глубже DEPTH px.
Заливка упирается в контур и насыщенные цвета, поэтому волосы, кожа и одежда
не страдают. Нужны pillow, numpy, scipy.

    python3 tools/defringe_sprites.py            # все спрайты на месте
    python3 tools/defringe_sprites.py a.webp     # только указанные
"""
import glob
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

DEPTH = 18  # насколько глубоко ореол может заходить от края, px
PALE_SAT = 0.34  # насыщенность ниже — «бледный» пиксель (остаток фона)
PALE_LUMA = 150
SOFT_ALPHA = 150  # прозрачнее этого — всегда ореол


def clean(path: str) -> int:
    rgba = np.array(Image.open(path).convert("RGBA"))
    rgb = rgba[..., :3].astype(np.float32)
    alpha = rgba[..., 3]
    top = rgb.max(-1)
    sat = (top - rgb.min(-1)) / np.maximum(top, 1.0)
    luma = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    outside = alpha < 16
    passable = (alpha < SOFT_ALPHA) | ((sat < PALE_SAT) & (luma > PALE_LUMA))
    reached = ndimage.binary_dilation(
        outside, structure=np.ones((3, 3), bool), iterations=DEPTH, mask=passable | outside
    )
    removed = reached & ~outside
    keep = (alpha >= 16) & ~removed
    # Мягкая кромка в 1 px, чтобы срез не был «лесенкой».
    edge = ndimage.gaussian_filter(keep.astype(np.float32), 0.8)
    new_alpha = np.where(keep, alpha * np.clip(edge * 1.6 - 0.3, 0.0, 1.0), 0).astype(np.uint8)
    rgba[..., 3] = new_alpha
    # Цвет под прозрачностью — от ближайшего видимого пикселя: при
    # масштабировании по краю не подмешивается белый.
    solid = new_alpha > 0
    _, nearest = ndimage.distance_transform_edt(~solid, return_indices=True)
    rgba[..., :3] = rgba[..., :3][nearest[0], nearest[1]]
    Image.fromarray(rgba).save(path, "WEBP", quality=90, alpha_quality=100, method=6, exact=True)
    return int(removed.sum())


if __name__ == "__main__":
    files = sys.argv[1:] or sorted(glob.glob("assets/story/*.webp"))
    for name in files:
        print(name, "убрано пикселей:", clean(name))
