shader_type canvas_item;

// Camouflage uniforms
uniform float camouflage_alpha_override : hint_range(0.0, 1.0) = 1.0;

// Flash uniforms
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float brightness_boost : hint_range(0.0, 0.5) = 0.18;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    
    // 1. Brightness boost (for flash effect)
    tex.rgb += brightness_boost;
    
    // 2. Damage flash (mixes with flash_color based on flash_strength)
    tex.rgb = mix(tex.rgb, flash_color.rgb, flash_strength);
    
    // 3. Camouflage transparency (multiply alpha)
    float final_alpha = tex.a * camouflage_alpha_override;
    
    COLOR = vec4(clamp(tex.rgb, 0.0, 1.0), final_alpha);
}