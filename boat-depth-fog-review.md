# Depth-gradient fog: review for the top-down boat camera

## Conclusion

The supplied shader is a useful **depth reconstruction + palette** example, not a drop-in replacement for this sea's atmosphere. Do not enable it globally as written. The repository already has low height-profile volumetric fog (`boat_rme4_fog.gdshader`) and water-material distance haze (`water_boat.gdshader`). Adding a full-frame gradient would stack another layer on both.

This review is based on supplied source and repository inspection, not Godot compilation/render/FPS measurements. No new fog pass or world material change is enabled by this increment.

## What the source actually does

- Samples screen color and opaque depth, reconstructs view-space position through `INV_PROJECTION_MATRIX`, uses `-view.z` for palette lookup.
- `linear_depth` is view-axis distance. With our orthographic, oblique top-down camera it is **not water depth**, distance from the boat, or height above water. The same horizontal sea plane has varying view depth across the picture; lifting/tilting/zooming the camera changes the result without a weather change.
- `fog_amount` scales the gradient lookup coordinate, not the final opacity. With default 0.15, only the first 15% of the gradient is used. Final blend is `fog_color.a * fog_strength`, not `fog_factor`. A gradient with constant alpha 0.5 therefore tints even near pixels by 50% at strength 1, including when amount is zero. A purpose-designed alpha gradient can make the original meaningful, but `amount` is not a reliable density control as named.
- This is a color post-effect, not participating fog. It will not itself scatter headlights, produce shafts or light fog around buoys.

## Renderer/depth caveats

Project default is Forward+; mobile fallback is GL Compatibility.

1. For Godot 4.3+ reverse-Z Forward+/Mobile, `POSITION = vec4(VERTEX.xy, 1.0, 1.0)` places a fullscreen quad at near depth. The supplied XY remap + raw Z convention matches the Vulkan-style clip-depth reconstruction. Compatibility needs its OpenGL NDC Z remap (`raw_depth * 2.0 - 1.0`) and renderer-aware handling; do not blindly reuse the Forward+ path.
2. Do not keep `depth_draw_always` for a fullscreen post-effect. It writes the quad's depth and can interfere with later transparent objects. Keep depth testing/writing configuration and render order explicit; a quad also needs correct CPU culling bounds.
3. A spatial screen-texture snapshot excludes normal later transparent rendering. Depth is usually opaque depth. Our water is transparent and has its own depth/shoreline processing: the sampled depth can represent sand/rocks below water rather than the visible wave surface. A reconstruction result cannot be assumed to be the waterline.
4. Avoid linearly filtering depth across object edges: it synthesizes positions between unrelated surfaces and creates halos. Nearest depth sampling is safer for reconstruction.
5. Handle background/sky depths and tiny `view.w`, and require `fog_far > fog_near`. Optional screen mipmaps are unnecessary for a plain color mix; do not introduce blur/mipmap generation just to recolor pixels.
6. In a future post-effect, preserve existing lower-layer postprocessing and avoid tinting the HUD. Fullscreen screen-copy/gradient cost still needs measurement. Correct inverse projection alone does not solve compositing with transparent water.

## Elements worth reusing

### 1. Best fit: a bathymetric gradient in the existing water material

Use **actual ground/sea depth already available in the water shader**, not camera depth, to pick a restrained shallow/deep palette. This could visually distinguish a bank shoulder from deep navigable water from above. Keep foam, normals, glitter, wake and practical-light contributions intact; do not replace the final color with a flat gradient overlay. This is a possible separate art experiment, not a changed palette in this commit.

### 2. Atmospheric option: height-limited, world-anchored mist pockets

Reconstruct world position if depth is genuinely needed (`INV_VIEW_MATRIX * view_position`), then use height relative to the sea and horizontal distance to the vessel, rather than just `-view.z`. From above, **sparse low patches between threats** are more useful than a distant-screen wash. Leave the cabin/upper hull exposed and the immediate maneuvering area readable. Existing FogVolume height/noise controls are a better foundation: they already interact with lights. Avoid making the camera push a visible moving clear-circle through fog; any vessel clearance should be soft and carefully tested.

### 3. Debug option: a temporary depth/height visualization

A false-color depth display could diagnose shoreline/depth mismatches and transparent-water assumptions. Keep it a developer-only view, not gameplay haze, and distinguish camera depth, world height and bathymetry explicitly.

## If prototyped later

For ordinary distance fog, separate palette location and density conceptually:

```
t = clamp((linear_depth - near) / max(far - near, epsilon), 0, 1)
rgba = gradient(t)
alpha = clamp(t * amount * strength * rgba.a, 0, 1)
color = mix(original, rgba.rgb, alpha)
```

This fixes the misleading amount control, but **does not fix** top-down geometry, water transparency or pass ordering. Those need a rendering design before enabling a shader. For this project prefer an optional experiment in the existing world-space fog or water material over a second blanket atmospheric pass.


## Implemented trial after user approval

Both optional interpretations now have independent session-only checkboxes in `SeaLookTrial`, initially on for comparison. Disabling returns the existing branches, not another redesigned look.

- **Depth palette:** a four-stop GradientTexture1D over real static bathymetry 0–14 m, blended at 35% into base water color before shoreline/foam/light/glitter processing. Uses `sea_level - ground`, not animated surface Y or camera depth. No fullscreen pass or water geometry change.
- **Mist pockets:** reuses existing broad/mid/height noise, removes the uniform low-profile fill in favor of a sparse smooth mask, and lowers the local ceiling from 1.2–2.6 m to 0.70–1.65 m. Same FogVolume, weather multiplier, lighting, color and emission; no new density texture reads, lights or raymarch loop. The legacy high profile is untouched by this trial.
- Fog comparison is disabled when the volumetric material is unavailable. The trial does not enable volumetric fog or change weather by itself. Mist may therefore be absent in clear weather or when atmospheric fog is disabled elsewhere.
- Controls are hidden during inspection/photo/map and raid modals. No new hotkeys or saved preferences. Resource zones, hull physics, wake and damage glitch are unchanged.

52 Python checks and GDScript parse checks pass; new controller lint passes. Native smoke A/B parameter checks are prepared, not run. No Godot shader compile/render/FPS confirmation in this environment. Compare near a shallow bank and on deeper water, then low weather-driven mist in evening/night; toggle each option separately. Do not infer successful art direction from source/math checks.
