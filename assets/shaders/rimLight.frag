#pragma language glsl3;
#pragma GCC optimize("Ofast");
precision highp float;

extern vec4 uFrameBounds;
extern float uRim_angle;
extern float uRim_distance;
extern float uRim_strength;
extern float uRim_threshold;
extern float uRim_angOffset;

extern Image altMask;
extern bool uRim_useAltMask;
extern float uRim_maskThreshold;

extern vec3 uRim_dropColor;

// color adjust
extern float uRim_hue;
extern float uRim_saturation;
extern float uRim_brightness;
extern float uRim_contrast;

extern float uRim_antialiasAmt;
extern vec2 uTextureSize;

const vec3 grayscaleValues = vec3(0.3098039215686275, 0.607843137254902, 0.0823529411764706);
const float e = 2.718281828459045;

vec3 applyHueRotate(vec3 aColor, float aHue) {
	float angleVal = radians(aHue);
	mat3 m1 = mat3(0.213, 0.213, 0.213, 0.715, 0.715, 0.715, 0.072, 0.072, 0.072);
	mat3 m2 = mat3(0.787, -0.213, -0.213, -0.715, 0.285, -0.715, -0.072, -0.072, 0.928);
	mat3 m3 = mat3(-0.213, 0.143, -0.787, -0.715, 0.140, 0.715, 0.928, -0.283, 0.072);
	mat3 m = m1 + cos(angleVal) * m2 + sin(angleVal) * m3;
	return m * aColor;
}

vec3 applySaturation(vec3 aColor, float value) {
	if(value > 0.0) { value = value * 3.0; }
	value = (1.0 + (value / 100.0));
	vec3 grayscale = vec3(dot(aColor, grayscaleValues));
	return clamp(mix(grayscale, aColor, value), 0.0, 1.0);
}

vec3 applyContrast(vec3 aColor, float value) {
	value = (1.0 + (value / 100.0));
	if(value > 1.0) {
		value = (((0.00852259 * pow(e, 4.76454 * (value - 1.0))) * 1.01) - 0.0086078159) * 10.0;
		value += 1.0;
	}
	return clamp((aColor - 0.25) * value + 0.25, 0.0, 1.0);
}

vec3 applyHSBCEffect(vec3 color) {
	color = color + ((uRim_brightness) / 255.0);
	color = applyHueRotate(color, uRim_hue);
	color = applyContrast(color, uRim_contrast);
	color = applySaturation(color, uRim_saturation);
	return color;
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float intensityPass(Image texture, vec2 fragCoord, float curThreshold, bool uMask) {
	vec4 col = Texel(texture, fragCoord);
	float maskIntensity = 0.0;

	if(uMask) {
		maskIntensity = mix(0.0, 1.0, Texel(altMask, fragCoord).b);
	}

	if(col.a == 0.0) return 0.0;

	float intensity = dot(col.rgb, vec3(0.3098, 0.6078, 0.0823));
	return maskIntensity > 0.0 ? float(intensity > uRim_maskThreshold) : float(intensity > curThreshold);
}

float antialias(Image texture, vec2 fragCoord, float curThreshold, bool uMask) {
	if (uRim_antialiasAmt <= 0.0) {
		return intensityPass(texture, fragCoord, curThreshold, uMask);
	}

	const int MAX_AA = 8;
	float AA_TOTAL_PASSES = uRim_antialiasAmt * uRim_antialiasAmt + 1.0;
	const float AA_JITTER = 0.5;

	float colorVal = intensityPass(texture, fragCoord, curThreshold, uMask);

	for (int i = 0; i < MAX_AA * MAX_AA; i++) {
		int x = i / MAX_AA;
		int y = i - (MAX_AA * int(i/MAX_AA));

		if (float(x) >= uRim_antialiasAmt || float(y) >= uRim_antialiasAmt) continue;

		vec2 offset = AA_JITTER * (2.0 * hash22(vec2(float(x), float(y))) - 1.0) / uTextureSize;
		colorVal += intensityPass(texture, fragCoord + offset, curThreshold, uMask);
	}

	return colorVal / AA_TOTAL_PASSES;
}

vec3 createDropShadow(Image texture, vec2 uv, vec3 col, float curThreshold, bool uMask) {
	float intensity = antialias(texture, uv, curThreshold, uMask);

	vec2 imageRatio = vec2(1.0/uTextureSize.x, 1.0/uTextureSize.y);

	vec2 checkedPixel = vec2(
		uv.x + (uRim_distance * cos(uRim_angle + uRim_angOffset) * imageRatio.x),
		uv.y - (uRim_distance * sin(uRim_angle + uRim_angOffset) * imageRatio.y)
	);

	float dropShadowAmount = 0.0;

	if(checkedPixel.x > uFrameBounds.x && checkedPixel.y > uFrameBounds.y &&
	   checkedPixel.x < uFrameBounds.z && checkedPixel.y < uFrameBounds.w) {
		dropShadowAmount = Texel(texture, checkedPixel).a;
	}

	col.rgb += uRim_dropColor.rgb * ((1.0 - (dropShadowAmount * uRim_strength)) * intensity);
	return col;
}

vec4 effect(mediump vec4 color, Image texture, mediump vec2 texture_coords, mediump vec2 screen_coords) {
	vec4 col = Texel(texture, texture_coords);
	if (col.a == 0.0) { discard; }

	vec3 unpremultipliedColor = col.a > 0.0 ? col.rgb / col.a : col.rgb;

	vec3 outColor = applyHSBCEffect(unpremultipliedColor);
	outColor = createDropShadow(texture, texture_coords, outColor, uRim_threshold, uRim_useAltMask);

	return vec4(outColor.rgb * col.a, col.a) * color;
}
