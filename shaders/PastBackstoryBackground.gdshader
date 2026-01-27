shader_type canvas_item;

uniform float grain_amount : hint_range(0.0, 1.0) = 0.05;
uniform float flicker_speed : hint_range(0.1, 5.0) = 0.1;
uniform float flicker_amount : hint_range(0.0, 0.1) = 0.03;
uniform vec4 tint_color : source_color = vec4(0.8, 0.7, 0.6, 0.3); // Subtle sepia tint
uniform vec4 base_color : source_color = vec4(0.235, 0.157, 0.059, 1.0); // DARK BROWN background

void fragment() {
    // Start with base brown color (not texture)
    vec4 color = base_color;
    
    // Apply sepia/brown tint over the base color
    color.rgb = mix(color.rgb, tint_color.rgb, tint_color.a);
    
    // Add film grain
    float grain = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453 + TIME) * 2.0 - 1.0;
    color.rgb += grain * grain_amount;
    
    // Add flicker
    float flicker = sin(TIME * flicker_speed * 2.3) * sin(TIME * flicker_speed * 1.7);
    color.rgb += flicker * flicker_amount;
    
    // Add vignette effect
    vec2 uv_centered = UV * 2.0 - 1.0;
    float vignette = 1.0 - dot(uv_centered, uv_centered) * 0.3;
    color.rgb *= vignette;
    
    COLOR = color;
}