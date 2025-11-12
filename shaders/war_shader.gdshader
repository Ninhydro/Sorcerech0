shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 0.0, 0.0, 0.3);
uniform float noise_intensity : hint_range(0.0, 0.5) = 0.5;

void fragment() {
    // Use the ColorRect's base color instead of texture
    vec4 base_color = COLOR;
    
    // Add some noise for war effect
    float noise = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);
    noise = (noise - 0.5) * 2.0 * noise_intensity * intensity;
    
    // Apply red tint based on intensity
    vec4 tinted = mix(base_color, tint_color, intensity * tint_color.a);
    
    // Add noise to RGB channels slightly differently for war effect
    tinted.r += noise * 0.3;
    tinted.g += noise * 0.1;
    tinted.b += noise * 0.1;
    
    // Increase contrast for dramatic effect
    tinted.rgb = mix(tinted.rgb, tinted.rgb * 1.2, intensity * 0.3);
    
    COLOR = tinted;
}