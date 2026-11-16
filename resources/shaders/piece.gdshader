// Build piece shader (spec 7.2): one instance uniform per paint region, so painting a piece
// never duplicates materials. Each part's material picks its region with `region`.
shader_type spatial;

instance uniform vec4 primary_color : source_color = vec4(1.0);
instance uniform vec4 secondary_color : source_color = vec4(1.0);
instance uniform vec4 trim_color : source_color = vec4(1.0);
uniform vec4 base_color : source_color = vec4(1.0);
uniform int region = 0;   // 0 none, 1 primary, 2 secondary, 3 trim

void fragment() {
	vec4 tint = region == 1 ? primary_color : (region == 2 ? secondary_color : (region == 3 ? trim_color : vec4(1.0)));
	ALBEDO = base_color.rgb * tint.rgb;
}
