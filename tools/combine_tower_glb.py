#!/usr/bin/env python3
"""Combine the user's corrected static GLB with the earlier lift animations.

The new GLB has no animation tracks. The two anchor transforms and their
parent relationship must match the earlier export; otherwise stop rather than
silently attaching animation to an incompatible model. Only the two animation
tracks are copied, not the old mesh data. The source files are never modified.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import struct

ANIMATED_ANCHORS = (
    "ANCHOR_LIFT_CAGE_center.001",
    "ANCHOR_LIFT_door_center.001",
)
REFERENCE_NODES = {"GROUND_REF", "WALK_LIMIT_area"}


def read_glb(path: Path) -> tuple[dict, bytes]:
    raw = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", raw)
    if magic != 0x46546C67 or version != 2 or total != len(raw):
        raise ValueError(f"Invalid GLB 2 file: {path}")
    json_len, json_type = struct.unpack_from("<II", raw, 12)
    if json_type != 0x4E4F534A:
        raise ValueError(f"No JSON chunk: {path}")
    document = json.loads(raw[20 : 20 + json_len])
    bin_len, bin_type = struct.unpack_from("<II", raw, 20 + json_len)
    if bin_type != 0x004E4942:
        raise ValueError(f"No BIN chunk: {path}")
    binary = raw[28 + json_len : 28 + json_len + bin_len]
    if len(document.get("buffers", [])) != 1 or "uri" in document["buffers"][0]:
        raise ValueError(f"Expected a single embedded buffer: {path}")
    return document, binary


def node_map(doc: dict) -> dict[str, int]:
    result: dict[str, int] = {}
    for i, node in enumerate(doc["nodes"]):
        name = node.get("name")
        if name in ANIMATED_ANCHORS:
            if name in result:
                raise ValueError(f"Duplicate anchor: {name}")
            result[name] = i
    if set(result) != set(ANIMATED_ANCHORS):
        raise ValueError(f"Missing required anchors: {set(ANIMATED_ANCHORS) - set(result)}")
    return result


def parent_map(doc: dict) -> dict[int, int]:
    return {child: parent for parent, node in enumerate(doc["nodes"]) for child in node.get("children", [])}


def combine(corrected: Path, donor: Path, output: Path) -> None:
    if output.resolve() in {corrected.resolve(), donor.resolve()}:
        raise ValueError("Output must not overwrite either source GLB")
    new, new_binary = read_glb(corrected)
    old, old_binary = read_glb(donor)
    new_anchors, old_anchors = node_map(new), node_map(old)
    if new.get("animations"):
        raise ValueError("Corrected file already has animations; review instead of overwriting them")
    new_parents, old_parents = parent_map(new), parent_map(old)
    for name in ANIMATED_ANCHORS:
        new_node, old_node = new["nodes"][new_anchors[name]], old["nodes"][old_anchors[name]]
        for prop in ("translation", "rotation", "scale", "matrix"):
            if new_node.get(prop) != old_node.get(prop):
                raise ValueError(f"Anchor {name} has incompatible {prop}")
        new_parent, old_parent = new_parents.get(new_anchors[name]), old_parents.get(old_anchors[name])
        new_parent_name = new["nodes"][new_parent].get("name") if new_parent is not None else None
        old_parent_name = old["nodes"][old_parent].get("name") if old_parent is not None else None
        if new_parent_name != old_parent_name:
            raise ValueError(f"Anchor {name} has incompatible parent")

    # The two optional editor guides must not cover the real landscape.
    for scene in new.get("scenes", []):
        scene["nodes"] = [i for i in scene.get("nodes", []) if new["nodes"][i].get("name") not in REFERENCE_NODES]

    binary = bytearray(new_binary[: new["buffers"][0]["byteLength"]])
    views = new.setdefault("bufferViews", [])
    accessors = new.setdefault("accessors", [])
    copied_views: dict[int, int] = {}
    copied_accessors: dict[int, int] = {}

    def copy_view(index: int) -> int:
        if index not in copied_views:
            view = copy.deepcopy(old["bufferViews"][index])
            if view.get("buffer", 0) != 0:
                raise ValueError("Unexpected external donor buffer")
            start = view.get("byteOffset", 0)
            contents = old_binary[start : start + view["byteLength"]]
            if len(contents) != view["byteLength"]:
                raise ValueError("Truncated donor buffer view")
            binary.extend(b"\0" * (-len(binary) % 4))
            view["byteOffset"] = len(binary)
            binary.extend(contents)
            copied_views[index] = len(views)
            views.append(view)
        return copied_views[index]

    def copy_accessor(index: int) -> int:
        if index not in copied_accessors:
            accessor = copy.deepcopy(old["accessors"][index])
            if "bufferView" in accessor:
                accessor["bufferView"] = copy_view(accessor["bufferView"])
            if "sparse" in accessor:
                for component in ("indices", "values"):
                    entry = accessor["sparse"][component]
                    entry["bufferView"] = copy_view(entry["bufferView"])
            copied_accessors[index] = len(accessors)
            accessors.append(accessor)
        return copied_accessors[index]

    animations = []
    for name in ANIMATED_ANCHORS:
        matches = [a for a in old.get("animations", []) if a.get("name") == name]
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one animation for {name}")
        animation = copy.deepcopy(matches[0])
        for channel in animation["channels"]:
            source_index = channel["target"]["node"]
            source_name = old["nodes"][source_index].get("name")
            if source_name != name:
                raise ValueError(f"Unexpected animation target: {source_name}")
            channel["target"]["node"] = new_anchors[source_name]
        for sampler in animation["samplers"]:
            sampler["input"] = copy_accessor(sampler["input"])
            sampler["output"] = copy_accessor(sampler["output"])
        animations.append(animation)
    new["animations"] = animations
    new["buffers"][0]["byteLength"] = len(binary)
    encoded = json.dumps(new, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    encoded += b" " * (-len(encoded) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    total = 12 + 8 + len(encoded) + 8 + len(binary)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(
        struct.pack("<III", 0x46546C67, 2, total)
        + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
        + struct.pack("<II", len(binary), 0x004E4942) + binary
    )
    print(f"Wrote {output}: corrected geometry + {len(animations)} original animations")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corrected", type=Path, default=Path("godot tower with lift2.glb"))
    parser.add_argument("--animation-source", type=Path, default=Path("assets/tower/animated_tower.glb"))
    parser.add_argument("--output", type=Path, default=Path("assets/tower/tower_delivery.glb"))
    args = parser.parse_args()
    combine(args.corrected, args.animation_source, args.output)
