shader_type spatial;
render_mode cull_disabled, blend_mix, unshaded;

uniform sampler2D noise_texture : hint_default_white;
uniform float use_custom_texture : hint_range(0.0, 1.0) = 0.0;
uniform float clouds_speed : hint_range(0.0, 20.0, 0.01) = 2.0;
uniform float clouds_direction : hint_range(-0.5, 0.5, 0.0) = 0.2;
uniform float clouds_scale : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float clouds_cutoff : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float clouds_fuzziness : hint_range(0.0, 2.0, 0.01) = 0.5;
uniform vec3 clouds_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float edge_fade : hint_range(0.0, 1.0, 0.01) = 0.15;

// Noise generation functions
const int PRIME_X = 501125321;
const int PRIME_Y = 1136930381;

float lerp(float a, float b, float t) {
    return a + t * (b - a);
}

float cubic_lerp(float a, float b, float c, float d, float t) {
    float p = d - c - (a - b);
    return t * t * t * p + t * t * (a - b - p) + t * (c - a) + b;
}

float ping_pong(float t) {
    t -= trunc(t * 0.5) * 2.0;
    return t < 1.0 ? t : 2.0 - t;
}

int hash(int seed, int x_primed, int y_primed) {
    return (seed ^ x_primed ^ y_primed) * 0x27d4eb2d;
}

float val_coord(int seed, int x_primed, int y_primed) {
    int hash = hash(seed, x_primed, y_primed);
    hash *= hash;
    hash ^= hash << 19;
    return float(hash) * (1.0 / 2147483648.0);
}

float single_value_cubic(int seed, float x, float y) {
    int x1 = int(floor(x));
    int y1 = int(floor(y));

    float xs = x - float(x1);
    float ys = y - float(y1);

    x1 *= PRIME_X;
    y1 *= PRIME_Y;
    int x0 = x1 - PRIME_X;
    int y0 = y1 - PRIME_Y;
    int x2 = x1 + PRIME_X;
    int y2 = y1 + PRIME_Y;
    int x3 = x1 + (PRIME_X << 1);
    int y3 = y1 + (PRIME_Y << 1);

    return cubic_lerp(
        cubic_lerp(val_coord(seed, x0, y0), val_coord(seed, x1, y0), val_coord(seed, x2, y0), val_coord(seed, x3, y0), xs),
        cubic_lerp(val_coord(seed, x0, y1), val_coord(seed, x1, y1), val_coord(seed, x2, y1), val_coord(seed, x3, y1), xs),
        cubic_lerp(val_coord(seed, x0, y2), val_coord(seed, x1, y2), val_coord(seed, x2, y2), val_coord(seed, x3, y2), xs),
        cubic_lerp(val_coord(seed, x0, y3), val_coord(seed, x1, y3), val_coord(seed, x2, y3), val_coord(seed, x3, y3), xs),
    ys) * (1.0 / (1.5 * 1.5));
}

const float FRACTAL_BOUNDING = 1.0 / 1.75;
const int OCTAVES = 5;
const float PING_PONG_STRENGTH = 2.0;
const float WEIGHTED_STRENGTH = 0.0;
const float GAIN = 0.5;
const float LACUNARITY = 2.0;

float gen_fractal_ping_pong(vec2 pos, int seed, float frequency) {
    float x = pos.x * frequency;
    float y = pos.y * frequency;
    float sum = 0.0;
    float amp = FRACTAL_BOUNDING;
    for (int i = 0; i < OCTAVES; i++) {
        float noise = ping_pong((single_value_cubic(seed++, x, y) + 1.0) * PING_PONG_STRENGTH);
        sum += (noise - 0.5) * 2.0 * amp;
        amp *= lerp(1.0, noise, WEIGHTED_STRENGTH);
        x *= LACUNARITY;
        y *= LACUNARITY;
        amp *= GAIN;
    }
    return sum * 0.5 + 0.5;
}

float calculate_edge_fade(vec2 uv) {
    vec2 fade = smoothstep(vec2(0.0), vec2(edge_fade), uv) * 
                smoothstep(vec2(0.0), vec2(edge_fade), 1.0 - uv);
    return fade.x * fade.y;
}

void fragment() {
    // Calculate UV coordinates for cloud movement
    vec2 base_uv = UV * clouds_scale;
    float time = TIME * clouds_speed * 0.01;
    float sin_x = sin(clouds_direction * PI * 2.0);
    float cos_y = cos(clouds_direction * PI * 2.0);
    vec2 clouds_movement = vec2(sin_x, cos_y) * time;
    
    float cloud_density;
    
    if (use_custom_texture > 0.5) {
        // Use custom texture
        cloud_density = texture(noise_texture, base_uv + clouds_movement).r;
    } else {
        // Generate procedural cloud noise
        float noise_top = gen_fractal_ping_pong((base_uv + clouds_movement), 0, 0.5);
        float noise_middle = gen_fractal_ping_pong((base_uv + clouds_movement * 0.89), 1, 0.75);
        float noise_bottom = gen_fractal_ping_pong((base_uv + clouds_movement * 0.79), 2, 1.0);
        
        // Combine noise layers
        float noise_bottom_smooth = smoothstep(clouds_cutoff, clouds_cutoff + clouds_fuzziness, noise_bottom);
        float noise_middle_smooth = smoothstep(clouds_cutoff, clouds_cutoff + clouds_fuzziness, noise_middle + noise_bottom_smooth * 0.2) * 1.1;
        float noise_top_smooth = smoothstep(clouds_cutoff, clouds_cutoff + clouds_fuzziness, noise_top + noise_middle_smooth * 0.4) * 1.2;
        
        cloud_density = clamp(noise_top_smooth + noise_middle_smooth + noise_bottom_smooth, 0.0, 1.0);
    }
    
    // Calculate edge fade
    float edge_alpha = calculate_edge_fade(UV);
    
    // Apply cloud color and transparency with edge fade
    ALBEDO = clouds_color;
    ALPHA = cloud_density * edge_alpha;
}