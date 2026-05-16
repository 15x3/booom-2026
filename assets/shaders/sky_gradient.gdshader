shader_type sky;

uniform vec3 color_top : source_color = vec3(0.04, 0.08, 0.30);
uniform vec3 color_horizon : source_color = vec3(0.28, 0.55, 0.85);
uniform vec3 color_bottom : source_color = vec3(0.75, 0.85, 0.95);
uniform float exponent_top : hint_range(0.1, 3.0) = 0.6;
uniform float exponent_bottom : hint_range(0.1, 3.0) = 0.4;

void sky() {
	float y = EYEDIR.y;
	if (y > 0.0) {
		COLOR = mix(color_horizon, color_top, pow(y, exponent_top));
	} else {
		COLOR = mix(color_horizon, color_bottom, pow(-y, exponent_bottom));
	}
}
