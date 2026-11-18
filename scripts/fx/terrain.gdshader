// (v0.35) The ground of a map, painted: a base texture and up to three more (a path, paving, a second ground) laid over
// it where the map's splat map says, each tiled across the map at its own size. The splat is tiny (a pixel for a few
// map units); a noise breaks the edges between the textures into a natural, uneven line, and a slow second sample of
// each texture plus a large faint mottling hide the tiling.
shader_type canvas_item;

uniform sampler2D splat : filter_linear, repeat_disable;
uniform sampler2D tex_base : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_r : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_g : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_b : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform vec2 map_size = vec2(1000.0, 800.0);
uniform vec4 units = vec4(340.0);          // map units one tile of each texture covers: base, r, g, b
uniform vec3 use = vec3(1.0);              // which of r, g, b this map has
uniform vec3 edges = vec3(0.18, 0.18, 0.34); // how soft the line between the base and the r, g, b textures is
uniform float rough = 0.32;                // how far the noise pushes that line about
uniform float macro = 0.10;                // the large faint mottling
uniform vec3 tint = vec3(1.0);
uniform float sat = 1.0;                   // below 1: the whole ground a little greyer
uniform vec4 gains = vec4(1.0);            // each texture's brightness: base, r, g, b
uniform bool cheap = false;                // light graphics: one sample a texture, no crossfade

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

// one texture at a map point: two samples at different offsets, crossfaded by a slow noise, so no repeat lines up
vec3 tex_at(sampler2D t, vec2 p, float u) {
	vec2 uv = p / u;
	if (cheap) {
		return texture(t, uv).rgb;
	}
	float k = smoothstep(0.38, 0.62, texture(noise, p / (u * 2.7)).g);
	return mix(texture(t, uv).rgb, texture(t, uv * vec2(-1.0, 1.0) + vec2(0.31, 0.57)).rgb, k);
}

float weight(float s, float n, float e) {
	return smoothstep(0.5 - e, 0.5 + e, s + (n - 0.5) * rough * 2.0);
}

void fragment() {
	vec2 suv = clamp(wpos / map_size, vec2(0.0), vec2(1.0));
	vec4 s = texture(splat, suv);
	float n = texture(noise, wpos / 140.0).r * 0.65 + texture(noise, wpos / 37.0).b * 0.35;
	vec3 c = tex_at(tex_base, wpos, units.x) * gains.x;
	if (use.z > 0.5 && s.b > 0.01) {
		c = mix(c, tex_at(tex_b, wpos, units.w) * gains.w, weight(s.b, n, edges.z));
	}
	if (use.x > 0.5 && s.r > 0.01) {
		c = mix(c, tex_at(tex_r, wpos, units.y) * gains.y, weight(s.r, n, edges.x));
	}
	if (use.y > 0.5 && s.g > 0.01) {
		c = mix(c, tex_at(tex_g, wpos, units.z) * gains.z, weight(s.g, 1.0 - n, edges.y));
	}
	float m = texture(noise, wpos / 1100.0).r;
	c *= 1.0 + (m - 0.5) * 2.0 * macro;
	c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, sat);
	COLOR = vec4(c * tint, 1.0);
}
