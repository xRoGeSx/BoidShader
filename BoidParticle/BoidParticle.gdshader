shader_type particles;


uniform sampler2D boid_data;
uniform sampler2D noise;

uniform vec2 scroll = vec2(0.05, 0.05);

void process() {
	ivec2 pos_image_size = textureSize(boid_data, 0);
	
	ivec2 texel_pos = ivec2(int(mod(float(INDEX),float(pos_image_size.x))),
							int(float(INDEX)/float(pos_image_size.x)));
						
	vec4 boid_pos_rot = texelFetch(boid_data, texel_pos, 0);
	
	mat2 scale_rot_mat = mat2(vec2(cos(boid_pos_rot.b), sin(boid_pos_rot.b)), // First column
							  vec2(-sin(boid_pos_rot.b), cos(boid_pos_rot.b))); // Second column
	
	scale_rot_mat *= 0.4;
	
	TRANSFORM[0].xy = scale_rot_mat[0];
	TRANSFORM[1].xy = scale_rot_mat[1];
	TRANSFORM[3].xy = vec2(boid_pos_rot.r, boid_pos_rot.g); 
	
	vec4 noise_texture = texture(noise, vec2(boid_pos_rot.r, boid_pos_rot.g) * scroll * TIME);
	//vec4 noise_texture2 = texture(noise, vec2(boid_pos_rot.r, boid_pos_rot.g) * scroll * TIME * scroll);
	//vec4 noise_texture3 = texture(noise, vec2(boid_pos_rot.r, boid_pos_rot.g) * scroll * TIME * scroll * scroll);
	//COLOR = vec4(noise_texture.r, noise_texture2.r,noise_texture3.r,1);
	if(boid_pos_rot.a == 1.0) { 
		COLOR = vec4(1.0, 0,0,1);
	} else if(boid_pos_rot.a == 4.0) { 
		COLOR = vec4(0,1.0,0,1);
	} else if (boid_pos_rot.a == 5.0) {
		COLOR = vec4(0,0,1,1);		
	} else if(boid_pos_rot.a > 5.0) {
		float color = boid_pos_rot.a / 200.0;
		COLOR = vec4(0,color,0,1);
	} else {
		COLOR = vec4(1,1,1,1);
		
	}

}
