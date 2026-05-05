shader_type spatial;
render_mode unshaded;

uniform sampler2D palette : repeat_disable, filter_nearest;
uniform vec3 light_dir : source_color = vec3(0.5, 1.0, 0.5);
uniform float ambient : hint_range(0, 0.5) = 0.15;

void fragment() {
	float NdotL = max(dot(normalize(NORMAL), normalize(light_dir)), 0.0);
	float lit = ambient + (1.0 - ambient) * NdotL;
	
	ivec2 pal_size = textureSize(palette, 0);
	int index = int(lit * float(pal_size.x - 1));
	index = clamp(index, 0, pal_size.x - 1);
	
	ALBEDO = texelFetch(palette, ivec2(index, 0), 0).rgb;
}
