#[compute]
#version 450

#include "shared.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

void main() {
    uint my_index = gl_GlobalInvocationID.x;

    vec2 position = positions.data[my_index];
    vec2 velocity = velocities.data[my_index];

    // if(my_index >= 1) return;

    // vec2 polygonCenter = vec2(0,0);
    // int verticies = 0;
    // for(int i = 0; i < polygonVerticiesLookup.data[0]; i++) {
    //   verticies++;
    //   polygonCenter += polygonVerticies.data[0];
    //   continue;
    // }
    // polygonCenter /= verticies;

    // if(distance(polygonCenter, position) < 500) {
    //   velocities.data[my_index] += normalize(polygonCenter - position) * 50.0; 
    // }

    // polygonVerticiesLookup.data[my_index] = int(position.x);
}
