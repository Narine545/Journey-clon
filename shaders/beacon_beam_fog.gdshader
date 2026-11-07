shader_type fog;
// Слабая дымка ТОЛЬКО в локальном конусе маяка выше низкого морского слоя.
// FogVolume — ребёнок SpotLight3D; UVW следует его вращению и наклону.
// Свет рассчитывает Godot. Нет emission, экранной заливки или raymarch-поста.
uniform float cone_tangent = 0.21255656; // tan(12 degrees)
uniform float beam_density : hint_range(0.0, 0.02) = 0.008;

void fog() {
    float along = (1.0 - UVW.z) * SIZE.z;
    vec2 radial = (UVW.xy - vec2(0.5)) * SIZE.xy;
    float radius = max(along * cone_tangent, 0.05);
    float cone = 1.0 - smoothstep(0.65, 1.0, length(radial) / radius);
    float ends = smoothstep(0.0, 1.5, along)
        * (1.0 - smoothstep(SIZE.z - 8.0, SIZE.z, along));
    DENSITY = beam_density * cone * ends;
    ALBEDO = vec3(0.85, 0.88, 0.90);
    EMISSION = vec3(0.0);
}
