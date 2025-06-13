#[compute]
#version 450

#include "shared.glsl"
#include "utils.glsl"

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

void main() {
    float width = parameters.data[9];
    float height = parameters.data[10];
    float friend_radius = parameters.data[2];

    float y = float(gl_GlobalInvocationID.y);
    float x = float(gl_GlobalInvocationID.x);

    vec2 position = vec2(x, y);
    int my_bin = getBinIndex(position);
    int[9] neighbourBins = int[](-1, -1, -1, -1, -1, -1, -1, -1, -1);
    getNeighbouringBins(my_bin, neighbourBins);

    float friends = 0;
    for(int neighbour_bin_index_lookup = 0; neighbour_bin_index_lookup < neighbourBins.length(); neighbour_bin_index_lookup++) {
        int neighbour_bin_index = neighbourBins[neighbour_bin_index_lookup];
        if(neighbour_bin_index == -1)
            continue;

        int bin_lookup_start = neighbour_bin_index == 0 ? 0 : binIndexTackLookup.data[neighbour_bin_index - 1];
        int bin_lookup_end = binIndexTackLookup.data[neighbour_bin_index];

        for(int lookup_index = bin_lookup_start; lookup_index < bin_lookup_end; lookup_index++) {
            int i = binBoidLookups.data[lookup_index];

            vec2 otherPosition = positions.data[i];
            if(otherPosition.x == -1)
                return;

            float dist = distance(position, otherPosition);
            if(dist < friend_radius) {
                friends += map(dist, 0.0, friend_radius - 1, 1.0, 0.0);
            }

        }
    }
    imageStore(heatmap_texture, ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y), vec4(friends, 0.0, 0.0, 0.0));

}