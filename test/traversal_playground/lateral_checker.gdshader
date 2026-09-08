shader_type spatial;
// World-space 25 cm squares stay fixed as the character moves past them.
uniform float square_size = 0.25;
uniform vec4 light_color : source_color = vec4(0.30, 0.72, 0.63, 1.0);
uniform vec4 dark_color : source_color = vec4(0.055, 0.19, 0.18, 1.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 n = abs(normalize(world_normal));
	vec2 plane = world_position.xy;
	if (n.y > n.x && n.y > n.z) { plane = world_position.xz; }
	else if (n.x > n.z) { plane = world_position.zy; }
	vec2 cell = floor(plane / max(square_size, 0.01));
	float alternate = mod(cell.x + cell.y, 2.0);
	ALBEDO = mix(dark_color.rgb, light_color.rgb, alternate);
	ROUGHNESS = 0.9;
}
