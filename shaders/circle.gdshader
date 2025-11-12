// circular_minimap_scaled.shader
shader_type canvas_item;

uniform float outline_width = 0.01;
uniform vec4 outline_color = vec4(1.0);
uniform float scale = 0.9; // 90% of container size

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 scaled_uv = (UV - center) / scale + center;
    
    // Only process if within scaled bounds
    if (abs(scaled_uv.x-0.5) > 0.5 || abs(scaled_uv.y-0.5) > 0.5) {
        discard;
    }
    
    float dist = distance(scaled_uv, center);
    float radius = 0.49;
    
    // Outline
    if (dist > radius && dist <= radius + outline_width) {
        COLOR = outline_color;
    }
    // Main content
    else if (dist <= radius) {
        COLOR = texture(TEXTURE, scaled_uv);
    }
    // Transparent
    else {
        discard;
    }
}