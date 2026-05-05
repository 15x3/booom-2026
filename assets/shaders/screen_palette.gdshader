shader_type spatial;
render_mode unshaded;

uniform sampler2D viewport_texture : repeat_disable, filter_nearest;
uniform sampler2D palette : repeat_disable, filter_nearest;

void fragment() {
	vec4 viewport_color = texture(viewport_texture, UV);
	float luminance = dot(viewport_color.rgb, vec3(0.299, 0.587, 0.114));
	
	ivec2 pal_size = textureSize(palette, 0);
	int index = int(luminance * float(pal_size.x - 1));
	index = clamp(index, 0, pal_size.x - 1);
	
	ALBEDO = texelFetch(palette, ivec2(index, 0), 0).rgb;
}
