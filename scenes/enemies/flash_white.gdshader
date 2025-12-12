shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 white = vec4(1.0, 1.0, 1.0, tex.a);

	// Normal sprite color (includes modulate)
	vec4 base = tex * COLOR;

	// Mix towards white (keep alpha)
	COLOR = mix(base, white, flash);
}
