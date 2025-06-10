#[compute]
#version 450

#include "shared.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

void main() {
    uint my_index = gl_GlobalInvocationID.x;
    int bin_amount = binParameters.amount;

    if(my_index > bin_amount - 1)
        return;

    binIndexLookup.data[my_index] = 0;
    barrier();

    for(int i = 0; i <= my_index; i++) {
        binIndexLookup.data[my_index] += binSum.data[i];
    }
    barrier();

    binIndexTackLookup.data[my_index] = 0;
    binIndexTackLookup.data[my_index] = binIndexLookup.data[my_index - 1];
}
