shader_type spatial;
render_mode unshaded;

uniform sampler2D palette : repeat_disable, filter_nearest;
uniform vec3 light_dir = vec3(0.5, 1.0, 0.5);
uniform float ambient = 0.15;

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 L = normalize(light_dir);
	float NdotL = max(dot(N, L), 0.0);
	float luminance = ambient + (1.0 - ambient) * NdotL;
	
	ivec2 pal_size = textureSize(palette, 0);
	int index = int(luminance * float(pal_size.x - 1));
	index = clamp(index, 0, pal_size.x - 1);
	
	ALBEDO = texelFetch(palette, ivec2(index, 0), 0).rgb;
}
