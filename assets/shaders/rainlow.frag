#pragma language glsl3;
#pragma GCC optimize("Ofast");
precision lowp float;
uniform float time;
uniform float scale;
uniform float intensity;
uniform float distortionStrength;
const float RAIN_SPEED = 800.0;
const float INV_SCALE = 0.1;
const float Y_SCALE = 0.03;
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}
vec4 effect(mediump vec4 color, Image tex, mediump vec2 uv, mediump vec2 screen_coords) {
	vec2 pos = screen_coords;
	vec2 distortedUV = uv;
	float accumulator = 0.0;
	float scales[2];
	scales[0] = 1.0;
	scales[1] = 2.5;
	for (int i = 0; i < 2; i++) {
		float sc = scales[i];
		vec2 p = pos * sc / scale;
		p *= INV_SCALE;
		p.x += p.y * 0.1;
		p.y -= time * RAIN_SPEED / sc;
		p.y *= Y_SCALE;
		vec2 idx = floor(p);
		float ix = idx.x;
		p.y += mod(ix, 2.0) * 0.5;
		idx.y = floor(p.y);
		p -= idx;
		vec2 d = abs(p - 0.5);
		float drop = max(d.x, d.y) - 0.1;
		if (drop < 0.0) {
			if (rand(idx) < mix(0.1, 1.0, intensity)) {
				float v = (1.0 + drop * 2.0) / sc;
				distortedUV.x += v * 0.01 * distortionStrength;
				distortedUV.y -= v * 0.002 * distortionStrength;
				accumulator += v * 0.3;
			}
		}
	}
	vec4 texcolor = Texel(tex, distortedUV);
	texcolor.rgb += vec3(0.05, 0.08, 0.1) * accumulator;
	texcolor.rgb = mix(texcolor.rgb, vec3(0.4, 0.5, 0.8), min(accumulator * 0.05, 0.2));
	return texcolor;
}
