#[compute]
#version 450

#include "shared.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

void main() {

    uint my_index = gl_GlobalInvocationID.x;
    float bin_amount = binParameters.amount;
    float boid_amount = parameters.data[0]; 

    float IMAGE_SIZE = parameters.data[1]; 
    ivec2 pixel_pos = ivec2(int(mod(my_index, IMAGE_SIZE)), int(my_index / IMAGE_SIZE));

    if(my_index < bin_amount) {
        binSum.data[my_index] = 0;
    }
    barrier();
    

    if(my_index >= boid_amount) return;

    int my_bin = bin.data[my_index];
    atomicAdd(binSum.data[my_bin], 1);

    imageStore(boid_texture, pixel_pos, vec4(0,0,0,0.0));
}
