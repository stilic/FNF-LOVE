#pragma language glsl3
// this one is for thorns bg effect lul
precision highp float;

extern float time;

highp vec2 wiggle(vec2 uv, float t, float amp, float freq) {
	uv.x += sin(uv.y * freq + t) * amp;
	uv.y += cos(uv.x * freq + t) * amp;
	uv = mix(uv, vec2(uv.x, uv.y + sin(t * 0.5) * 0.002), 0.5);
	return uv;
}

highp vec4 effect(mediump vec4 color, Image tex, mediump vec2 coords, mediump vec2 _) {
	vec2 uv = wiggle(coords, time, 0.016, 5.54);
	return Texel(tex, uv) * color;
}
