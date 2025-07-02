#pragma language glsl3;

// effect doesn't even appears on mediump
precision highp float;

uniform float time;
uniform float scale;
uniform float intensity;
uniform float distortionStrength;

const float RAIN_SPEED = 8.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

highp float rainDrop(vec2 p, float sc, out float distortAmount) {
	p *= 0.1;
	p.x += p.y * 0.1;
	p.y -= time * (RAIN_SPEED * 100.0) / sc;
	p.y *= 0.03;

	float ix = floor(p.x);
	float iy = floor(p.y);
	vec2 idx = vec2(ix, iy);

	p.y += mod(ix, 2.0) * 0.5 + (rand(vec2(ix)) - 0.5) * 0.3;
	iy = floor(p.y);
	idx = vec2(ix, iy);

	p -= vec2(ix, iy);
	p.x += (rand(idx.yx) * 2.0 - 1.0) * 0.35;
	vec2 d = abs(p - 0.5);
	float drop = max(d.x * 0.8, d.y * 0.5) - 0.1;

	distortAmount = 0.0;
	if (drop < 0.0) {
		float center = length(p - 0.5);
		distortAmount = smoothstep(0.0, 0.4, -drop) * smoothstep(0.0, 0.2, center);
	}

	bool empty = rand(idx) < mix(1.0, 0.1, intensity);
	return empty ? 1.0 : drop;
}

vec4 effect(mediump vec4 color, Image tex, mediump vec2 uv, mediump vec2 screen_coords) {
	vec2 pos = screen_coords;
	vec2 originalPos = pos;

	vec2 distortedUV = uv;
	float totalDistortion = 0.0;
	float maxDistortScale = 3.0;
	float rainAmount = 0.0;

	float scales[3] = float[3](1.0, 2.0, 3.0);

	for (int i = 0; i < 3; i++) {
		float sc = scales[i];
		float offset = float(i) * 500.0;
		float distortAmount;

		float drop = rainDrop(pos * sc / scale + offset, sc, distortAmount);

		if (drop < 0.0) {
			vec2 dir = normalize(pos - originalPos + vec2(0.01, 0.01));

			float distFactor = distortAmount * distortionStrength * (sc / maxDistortScale);
			distortedUV += dir * distFactor;
			totalDistortion += distFactor;
			rainAmount += (1.0 - rainAmount) * 0.75;
		}
	}

	vec4 texcolor = Texel(tex, distortedUV);
	vec3 rainAtmosphere = vec3(0.4, 0.5, 0.8);
	vec3 finalColor = mix(texcolor.rgb, rainAtmosphere, 0.1 * rainAmount);
	return vec4(finalColor, texcolor.a);
}
