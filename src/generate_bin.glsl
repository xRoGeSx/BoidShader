#[compute]
#version 450

#include "shared.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

void main() {
    uint my_index = gl_GlobalInvocationID.x;
    float LIST_SIZE = parameters.data[0]; 
    int bin_size = binParameters.size;
    float width = parameters.data[9];

    if(positions.data[my_index].x == -1) return;
    if(my_index > LIST_SIZE) return;

    vec2 position = positions.data[my_index];

    int my_bin = 
       int(position.x / (bin_size)) 
     + int(position.y / (bin_size)) * int(ceil(width / bin_size));
    bin.data[my_index] = my_bin;
}
