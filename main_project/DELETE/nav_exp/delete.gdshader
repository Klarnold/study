shader_type spatial;

uniform float add_scale: hint_range(0.0, 1.0, 0.1);
uniform vec4 color: source_color;

void vertex() {
	VERTEX *= (1. + add_scale);
}

void fragment() {
	ALBEDO = color.xyz;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
