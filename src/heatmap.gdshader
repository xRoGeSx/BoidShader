shader_type canvas_item;

float map(float value, float inMin, float inMax, float outMin, float outMax) {
  return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}


uniform int[50000] boid_heatmap;
varying vec2 vertex_local;

const vec2 SIZE = vec2(500,  500);

void vertex() {
	vertex_local = VERTEX;
}


void fragment() {
	COLOR  = vec4(0, 0, 0, 0);
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
