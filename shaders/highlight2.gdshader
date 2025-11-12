shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_thickness : hint_range(0.01, 0.1) = 0.03;

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    vec4 final_color = base_color;
    
    // Only process if current pixel is not fully opaque
    if (base_color.a < 0.95) {
        float outline_strength = 0.0;
        
        // Check surrounding pixels in a circular pattern
        for (int x = -2; x <= 2; x++) {
            for (int y = -2; y <= 2; y++) {
                if (x == 0 && y == 0) continue; // Skip center
                
                vec2 offset = vec2(float(x), float(y)) * outline_thickness;
                vec4 sample = texture(TEXTURE, UV + offset);
                outline_strength = max(outline_strength, sample.a);
            }
        }
        
        // Apply outline only to edges, not the interior
        if (outline_strength > 0.8 && base_color.a < 0.5) {
            final_color = outline_color;
            final_color.a = outline_strength; // Maintain transparency
        }
    }
    
    COLOR = final_color;
}