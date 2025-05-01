#[compute]
#version 450

#include "shared.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

void main() {

    uint my_index = gl_GlobalInvocationID.x;
    float bin_amount = binParameters.amount;
    float boid_amount = parameters.data[0]; 

    if(my_index < bin_amount) {
        binSum.data[my_index] = 0;
    }
    barrier();
    

    if(my_index > boid_amount) return;
    
    int my_bin = bin.data[my_index];
    atomicAdd(binSum.data[my_bin], 1);
}
