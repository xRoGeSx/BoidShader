#[compute]
#version 450

#include "shared.glsl"
#include "utils.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

void main() {

    uint my_index = gl_GlobalInvocationID.x;
    float bin_amount = binParameters.amount;
    float boid_amount = parameters.data[0];

    float IMAGE_SIZE = parameters.data[1];
    ivec2 pixel_pos = ivec2(int(mod(my_index, IMAGE_SIZE)), int(my_index / IMAGE_SIZE));

    if(positions.data[my_index].x == -1)
        return;

    if(my_index < bin_amount) {
        binSum.data[my_index] = 0;
    }
    barrier();

    if(my_index >= boid_amount)
        return;

    int my_bin = bin.data[my_index];
    atomicAdd(binSum.data[my_bin], 1);

    imageStore(boid_texture, pixel_pos, vec4(0, 0, 0, 0.0));

    // vec2 target = targets.data[0];
    // int tmy_bin = getBinIndex(target);
    // int[9] tneighbourBins = int[](-1, -1, -1, -1, -1, -1, -1, -1, -1);
    // getNeighbouringBins(tmy_bin, tneighbourBins);

    // for(int neighbour_bin_index_lookup = 0; neighbour_bin_index_lookup < tneighbourBins.length(); neighbour_bin_index_lookup++) {

    //     int neighbour_bin_index = tneighbourBins[neighbour_bin_index_lookup];
    //     if(neighbour_bin_index == -1)
    //         continue;

    //     int bin_lookup_end = binIndexTackLookup.data[neighbour_bin_index];
    //     int bin_lookup_start = neighbour_bin_index == 0 ? 0 : binIndexTackLookup.data[neighbour_bin_index - 1];

    //     for(int lookup_index = bin_lookup_start; lookup_index < bin_lookup_end - 1; lookup_index++) {
    //         int i = binBoidLookups.data[lookup_index];
    //         int detection = 0;
    //         if(my_index == i)
    //             continue;
    //         vec2 otherPosition = positions.data[i];
    //         vec2 otherVelocity = velocities.data[i];
    //         float dist = distance(target, otherPosition);
    //         if(dist < 50.0) {
    //             detection = 4;
    //         }
    //         ivec2 pixel_pos2 = ivec2(int(mod(i, IMAGE_SIZE)), int(i / IMAGE_SIZE));
    //         vec4 old_texture_pixel = imageLoad(boid_texture, pixel_pos);
    //         imageStore(boid_texture, pixel_pos2, vec4(old_texture_pixel.x, old_texture_pixel.y, old_texture_pixel.z, detection));

    //     }
    // }

}
