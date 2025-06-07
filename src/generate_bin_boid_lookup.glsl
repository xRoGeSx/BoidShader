#[compute]
#version 450

#include "shared.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;



void main() {
    uint my_index = gl_GlobalInvocationID.x;
    float LIST_SIZE = parameters.data[0]; 
    int bin_size = binParameters.size;
    int bin_amount = binParameters.amount;
    float width = parameters.data[9];
    if(my_index > LIST_SIZE) return;
    
    int my_bin = bin.data[my_index];
    
    int prev_index = atomicAdd(binIndexTackLookup.data[my_bin], 1);
    binBoidLookups.data[prev_index] = int(my_index);
}
