# Shader references and attribution

## Distance Gradient Fog 4.3+

- Author: **Koaleszenz** — https://godotshaders.com/author/koaleszenz/
- Source: https://godotshaders.com/shader/distance-gradient-fog-4-3/
- Author verified through the site's WordPress oEmbed metadata for that URL.
- The page labels shader code/snippets **MIT**. Images/videos and depicted demo assets are explicitly excluded from that grant.
- The author describes the atmosphere as inspired by *Among Trees* and credits the Abandoned Spaceship demo for presentation. Neither that demo nor its assets were imported here.
- Repository use: acknowledged inspiration for the depth-to-gradient concept. Our `water_boat.gdshader` implementation uses **world bathymetry**, not the author's full-screen view-depth pass. No original fog shader code was imported. See `boat-depth-fog-review.md` for the technical differences.

## Chromatic Aberration Sphere (Godot 4.x)

- Author: **AlexZero** (GodotShaders profile `kitsunekotta`) — https://godotshaders.com/author/kitsunekotta/
- Source: https://godotshaders.com/shader/chromatic-aberration-sphere/
- The page labels shader code/snippets **MIT**, excluding images/videos and depicted assets.
- Repository status: **independent debug prototype now available** in `sphere_mines.gd` / `sphere_mine.gdshader`. The full reference snippet was supplied by the user, but its screen-texture/refraction/star code was not copied. This prototype uses a transparent Fresnel shell, not actual chromatic refraction. See `sphere-mine-proposal.md`.

Both source pages and gradient author metadata were retrieved during this change. The license statements above apply to those code snippets, not to unrelated materials or the entire repository. When distributing an actual copied adaptation, retain the original copyright/permission notice and MIT license with it. Current palette code is an independently written conceptual adaptation, and the sphere has not been copied into an executable shader.

## Fireball or Candle Fire Shader

- Author: **Muhammad Mujtaba**, credited in the user-supplied shader header as **MIT License**.
- Source: https://godotshaders.com/shader/fireball-or-candle-fire-shader/
- Implementation: `shaders/raid_fireball.gdshader` adapts the supplied gradient-noise function into a bounded three-octave spatial effect. The original canvas-item gradient/compositing/neon pass is not reproduced verbatim; head/tail masks are written for the 3D projectile test. Shader includes author attribution and the MIT permission/warranty notice. No images, videos or textures imported.
- `scripts/raid_fireballs.gd` is a visual-only camera-plane MultiMesh, not a change to projectile mechanics.

## Particle Process v2 — reference only

- Source supplied by user: https://godotshaders.com/shader/particle-process-v2/
- No code imported or enabled in this change. The supplied header describes conversion from Godot 4.1.rc2 ParticleProcessMaterial and separately credits Isaac Cohen for curl-noise permission. Author/license and upstream notices must be verified before any copied adaptation. No license or authorship inferred merely from the other shaders on this page.
