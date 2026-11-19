// Build piece shader (spec 7.2, 11.3): one instance uniform per paint region, so painting a
// piece never duplicates materials. Each material picks its region with `region`.
// Placeholder boxes: base_color * dye. Textured models: the texture, or when the region is
// painted (dye alpha 1) the dye colour shaded by the texture's brightness.
shader_type spatial;

instance uniform vec4 primary_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
instance uniform vec4 secondary_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
instance uniform vec4 trim_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 base_color : source_color = vec4(1.0);
uniform int region = 0;   // 0 none, 1 primary, 2 secondary, 3 trim
uniform bool use_texture = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float lighten = 0.0;   // loose (unfastened) pieces read paler

void fragment() {
	vec4 tint = region == 1 ? primary_color : (region == 2 ? secondary_color : (region == 3 ? trim_color : vec4(1.0, 1.0, 1.0, 0.0)));
	if (use_texture) {
		vec3 tex = texture(albedo_tex, UV).rgb;
		float l = dot(tex, vec3(0.299, 0.587, 0.114));
		vec3 painted = clamp(tint.rgb * (0.55 + 0.9 * l), 0.0, 1.0);
		ALBEDO = mix(mix(tex, painted, tint.a), vec3(1.0), lighten);
	} else {
		ALBEDO = base_color.rgb * tint.rgb;
	}
}
