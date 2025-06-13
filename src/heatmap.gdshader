shader_type canvas_item;

float map(float value, float inMin, float inMax, float outMin, float outMax) {
  return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

varying vec2 vertex_local;
uniform sampler2D heatmap;


const vec2 SIZE = vec2(1152,  648);

void vertex() {
	vertex_local = VERTEX;
}


void fragment() {
	
	ivec2 pos_image_size = textureSize(heatmap, 0);
	int x = int(map(SCREEN_UV.x, 0, 1, 0, float(pos_image_size.x)));
	int y = int(map(SCREEN_UV.y, 0, 1, 0, float(pos_image_size.y)));

	ivec2 texel_pos = ivec2(int(vertex_local.x), int(vertex_local.y));

	vec4 heatmap_pixel = texelFetch(heatmap, texel_pos, 0);


	float opacity = float(heatmap_pixel.x) / 6.0;
	//float debug = float(index) / 746496.0;
	
	COLOR  = vec4(opacity, 0, 0, opacity);
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
