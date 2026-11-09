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
- Repository status: **design/reference only; sphere shader and gameplay effect not imported or enabled yet**. The full snippet was supplied by the user. See `sphere-mine-proposal.md` before implementing.

Both source pages and gradient author metadata were retrieved during this change. The license statements above apply to those code snippets, not to unrelated materials or the entire repository. When distributing an actual copied adaptation, retain the original copyright/permission notice and MIT license with it. Current palette code is an independently written conceptual adaptation, and the sphere has not been copied into an executable shader.
