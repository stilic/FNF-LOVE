#pragma language glsl3;
#pragma GCC optimize("Ofast");

precision highp float;

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

float rainDrop(vec2 p, float sc, out float distortAmount) {
	p *= INV_SCALE;
	p.x += p.y * 0.1;
	p.y -= time * RAIN_SPEED / sc;
	p.y *= Y_SCALE;

	vec2 idx = floor(p);
	float ix = idx.x;

	p.y += mod(ix, 2.0) * 0.5 + (rand(vec2(ix)) - 0.5) * 0.3;
	idx.y = floor(p.y);

	p -= idx;
	p.x += (rand(idx.yx) * 2.0 - 1.0) * 0.35;

	vec2 d = abs(p - 0.5);
	float drop = max(d.x * 0.8, d.y * 0.5) - 0.1;

	distortAmount = 0.0;
	if (drop < 0.0) {
		float center = length(p - 0.5);
		distortAmount = smoothstep(0.0, 0.4, -drop) * smoothstep(0.0, 0.2, center);
	}

	return (rand(idx) < mix(1.0, 0.1, intensity)) ? 1.0 : drop;
}

vec4 effect(mediump vec4 color, Image tex, mediump vec2 uv, mediump vec2 screen_coords) {
	vec2 pos = screen_coords;
	vec2 distortedUV = uv;

	float rainSum = 0.0;
	vec3 accumulator = vec3(0.0);

	float scales[4];
	scales[0] = 1.0;
	scales[1] = 1.8;
	scales[2] = 2.6;
	scales[3] = 4.8;

	float offsets[4];
	offsets[0] = 0.0;
	offsets[1] = 500.0;
	offsets[2] = 1000.0;
	offsets[3] = 1500.0;

	for (int i = 0; i < 4; i++) {
		float sc = scales[i];
		float dummy;
		float r = rainDrop(pos * sc / scale + offsets[i], sc, dummy);

		if (r < 0.0) {
			float v = (1.0 - exp(r * 5.0)) / sc * 2.0;
			distortedUV.x += v * 0.01 * distortionStrength;
			distortedUV.y -= v * 0.002 * distortionStrength;
			accumulator += vec3(0.1, 0.15, 0.2) * v;
			rainSum += (1.0 - rainSum) * 0.75;
		}
	}

	vec4 texcolor = Texel(tex, distortedUV);
	vec3 finalRGB = texcolor.rgb + accumulator;
	finalRGB = mix(finalRGB, vec3(0.4, 0.5, 0.8), 0.1 * rainSum);

	return vec4(finalRGB, texcolor.a);
}
