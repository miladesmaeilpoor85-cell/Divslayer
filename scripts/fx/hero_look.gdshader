shader_type canvas_item;
// (v0.20) Hero looks: recolours the cloth a mask marks (tools/make_hero_masks.py) with a look's three colours, keeping the
// drawing's shading. Mask R: full recolour; G: half (the paladin's plate). A pixel as bright as the cloth's mean (`key`)
// takes `mid`; darker ones run toward `dark`, brighter ones toward `light`.

uniform sampler2D mask_tex : filter_linear;
uniform vec3 mid = vec3(0.72, 0.39, 0.18);
uniform vec3 dark = vec3(0.43, 0.23, 0.11);
uniform vec3 light = vec3(0.88, 0.64, 0.24);
uniform float key = 0.4;
uniform float amount = 1.0;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 mk = texture(mask_tex, UV).rg;
	float m = clamp(mk.r + mk.g * 0.5, 0.0, 1.0) * amount;
	float l = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float t = clamp((l - key) / 0.22, -1.0, 1.0);
	vec3 rc = t < 0.0 ? mix(mid, dark, -t) : mix(mid, light, t * 0.8);
	COLOR = vec4(mix(tex.rgb, rc, m), tex.a) * vcol;
}
