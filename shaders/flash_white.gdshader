shader_type canvas_item;

uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float brightness_boost : hint_range(0.0, 0.5) = 0.18; // 👈 NEW

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Base brighten (prevents dark boss)
    tex.rgb += brightness_boost;

    // Damage flash
    tex.rgb = mix(tex.rgb, flash_color.rgb, flash_strength);

    COLOR = vec4(clamp(tex.rgb, 0.0, 1.0), tex.a);
}
