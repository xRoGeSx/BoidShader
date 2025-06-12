#[compute]
#version 450

#include "shared.glsl"
#include "utils.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

int getBinIndex2(vec2 position) {
    float width = parameters.data[9];

    int bin_size = binParameters.size;
    int horizontal_bin_amount = int(ceil(width / bin_size));
    int x = int(floor(position.x / bin_size));
    int y = int(floor(position.y / bin_size));
    int my_bin = x + y * horizontal_bin_amount;

    return my_bin;
}

void getNeighbouringBins2(int binIndex, inout int neighbours[9]) {
    float width = parameters.data[9];
    int bin_amount = int(binParameters.amount);
    int bin_size = binParameters.size;
    int horizontal_bin_amount = int(ceil(width / bin_size));
    bool isLeftEdge = binIndex % horizontal_bin_amount == 0;
    bool isRightEdge = binIndex == horizontal_bin_amount;
    bool isTopEdge = bin_size < bin_amount;
    bool isBottomEdge = bin_amount - binIndex < horizontal_bin_amount;

    neighbours[0] = binIndex;
    if(!isLeftEdge) {
        neighbours[1] = binIndex + 1;
        neighbours[2] = binIndex - 1;
    }

    // int iteration = 0;
    // for(int x = -1; x <= 1; x++) {
    //     for(int y = -1; y <= 1; y++) {
    //         iteration++;
    //         int neighbour_bin_index = binIndex + x + y * horizontal_bin_amount;
    //         if(neighbour_bin_index < 0 || neighbour_bin_index > bin_amount) {
    //             neighbours[iteration] = -1;
    //             continue;
    //         }
    //         neighbours[iteration] = neighbour_bin_index;
    //     }
    // }
}

void processBoidCollision(int my_index, inout vec2 result[4]) {
    int watching_index = 0;
    float IMAGE_SIZE = parameters.data[1];
    ivec2 pixel_pos = ivec2(int(mod(my_index, IMAGE_SIZE)), int(my_index / IMAGE_SIZE));

    float width = parameters.data[9];

    float friend_radius = parameters.data[2];
    float avoid_radius = parameters.data[3];

    int bin_size = binParameters.size;

    vec2 cohesion = vec2(0, 0);
    vec2 separation = vec2(0, 0);
    vec2 alignment = vec2(0, 0);
    int friends = 0;
    int avoids = 0;

    vec2 position = positions.data[my_index];

    int my_bin = getBinIndex2(position);

    int[9] neighbourBins = int[](-1, -1, -1, -1, -1, -1, -1, -1, -1);
    getNeighbouringBins2(my_bin, neighbourBins);

    for(int neighbour_bin_index_lookup = 0; neighbour_bin_index_lookup < neighbourBins.length(); neighbour_bin_index_lookup++) {

        int neighbour_bin_index = neighbourBins[neighbour_bin_index_lookup];
        if(neighbour_bin_index == -1)
            continue;

        int bin_lookup_end = binIndexTackLookup.data[neighbour_bin_index];
        int bin_lookup_start = neighbour_bin_index == 0 ? 0 : binIndexTackLookup.data[neighbour_bin_index - 1];

        for(int lookup_index = bin_lookup_start; lookup_index < bin_lookup_end - 1; lookup_index++) {

            int i = binBoidLookups.data[lookup_index];
            int detection = 0;
            if(my_index == i)
                continue;

            vec2 otherPosition = positions.data[i];
            vec2 otherVelocity = velocities.data[i];

            float dist = distance(position, otherPosition);

            if(dist < friend_radius) {
                detection = 1;

                friends++;
                alignment += otherVelocity;
                cohesion += otherPosition;
                if(dist < avoid_radius) {
                    avoids++;
                    separation += position - otherPosition;
                }
            }

        }
    }
    result[0] = cohesion;
    result[1] = separation;
    result[2] = alignment;
    result[3] = vec2(friends, avoids);
    return;
}

vec4 processPolygonCollision(int polygon_index, int boid_index, inout int detection_type) {

    vec2 position = positions.data[boid_index];
    vec2 velocity = velocities.data[boid_index];
    vec2 initialVelocity = velocity;
    vec2 polygonCenter = vec2(0, 0);
    int verticies = 0;
    float ATTRACTION_RANGE = 40.0;
    float EDGE_AVOIDANCE_RANGE = 7.0;
    int VISION_RESOLUTION = 60;
    float VISION_ANGLE = M_PI;
    int start = polygon_index == 0 ? 0 : polygonVerticiesLookup.data[polygon_index - 1];
    int end = polygonVerticiesLookup.data[polygon_index];

    for(int i = start; i < end; i++) {
        verticies++;
        polygonCenter += polygonVerticies.data[i];
        continue;
    }
    polygonCenter /= verticies;

    float separation_factor_mod = 1.0;

    float closestEdge = 9999.9;
    vec2 closestEdgeDirection = vec2(0, 0);
    int numberOfIntersections = 0;

    float step = VISION_ANGLE / VISION_RESOLUTION;

    for(int i = start; i < end; i++) {
        vec2 ray = position;
        vec2 rayEnd = position + velocity * ATTRACTION_RANGE;
        vec2 edgeStart = polygonVerticies.data[i];
        vec2 edgeEnd = polygonVerticies.data[i == end - 1 ? start : i + 1];
        for(int angleStep = -VISION_RESOLUTION / 2; angleStep < VISION_RESOLUTION / 2; angleStep++) {
            vec2 intersection = raycast(edgeStart, edgeEnd, ray, rotateVector(ray, rayEnd, angleStep * step));
            float distanceToEdge = length(intersection - position);
            if(closestEdge > distanceToEdge) {
                closestEdge = distanceToEdge;
                closestEdgeDirection = intersection - position;
            }
        }

        if(ray.y > edgeStart.y && ray.y > edgeEnd.y)
            continue;
        if(ray.y < edgeStart.y && ray.y < edgeEnd.y)
            continue;
        if(ray.x < edgeStart.x + ((ray.y - edgeStart.y) / (edgeEnd.y - edgeStart.y)) * (edgeEnd.x - edgeStart.x))
            numberOfIntersections++;
        continue;

    }

    bool inside = numberOfIntersections % 2 != 0;
    /* TODO: this need */
    if(inside) {
        separation_factor_mod *= 5;
        velocity += normalize(polygonCenter - position) * -10.0;
        if(closestEdge < EDGE_AVOIDANCE_RANGE) {
            detection_type = int(distance(polygonCenter, position));
            velocity += normalize(closestEdgeDirection) * -150.0;
        }
    } else if(closestEdge < ATTRACTION_RANGE) {
        velocity += normalize(closestEdgeDirection) * 120.0;
    }
    vec2 modVelocity = velocity - initialVelocity;
    return vec4(modVelocity.x, modVelocity.y, separation_factor_mod, 0.0);
}

void main() {

    uint my_index = gl_GlobalInvocationID.x;
    int watching_index = 0;

    float IMAGE_SIZE = parameters.data[1];
    ivec2 pixel_pos = ivec2(int(mod(my_index, IMAGE_SIZE)), int(my_index / IMAGE_SIZE));

    float LIST_SIZE = parameters.data[0];

    if(positions.data[my_index].x == -1)
        return;
    if(my_index > LIST_SIZE)
        return;

    float min_vel = parameters.data[4];
    float max_vel = parameters.data[5];
    float alignment_factor = parameters.data[6];
    float cohesion_factor = parameters.data[7];
    float separation_factor = parameters.data[8];
    float width = parameters.data[9];
    float height = parameters.data[10];
    float delta = parameters.data[11];

    int bin_size = binParameters.size;

    vec2 position = positions.data[my_index];
    vec2 velocity = velocities.data[my_index];
    vec2 target = targets.data[0];

    vec4 old_texture_pixel = imageLoad(boid_texture, pixel_pos);
    int detection_type = int(old_texture_pixel.a);
    if(my_index == watching_index) {
        detection_type = 4;
    }

    vec2[4] boidCollisionResult = vec2[](vec2(0, 0), vec2(0, 0), vec2(0, 0), vec2(0, 0));

    for(int polygonIndex = 0; polygonIndex < polygonVerticiesLookup.data.length(); polygonIndex++) {
        if(polygonVerticiesLookup.data[polygonIndex] == 0)
            break;
        vec4 polygonCollisionResult = processPolygonCollision(polygonIndex, int(my_index), detection_type);
        velocity += polygonCollisionResult.xy;
        separation_factor *= polygonCollisionResult.z;
    }

    processBoidCollision(int(my_index), boidCollisionResult);

    vec2 cohesion = boidCollisionResult[0];
    vec2 separation = boidCollisionResult[1];
    vec2 alignment = boidCollisionResult[2];
    int friends = int(boidCollisionResult[3].x);
    int avoids = int(boidCollisionResult[3].y);

    if(friends > 0) {
        velocity += normalize(alignment / friends) * alignment_factor;
        velocity += normalize(cohesion / friends - position) * cohesion_factor;
    }
    if(avoids > 0) {
        velocity += normalize(separation) * separation_factor;
    }

    float vel_magnitude = clamp(length(velocity), min_vel, max_vel);
    velocity = vel_magnitude * normalize(velocity);

    // if(distance(position, target) < 325.0) {
    //     velocity += normalize(target - position) * 50.0;
    // }
    position += velocity * delta;

    velocities.data[my_index].xy = velocity;
    positions.data[my_index].xy = position;

    float rotation = velocityToRotation(velocity);

    imageStore(boid_texture, pixel_pos, vec4(position.x, position.y, rotation, detection_type));

    if(positions.data[my_index].x > width) {
        positions.data[my_index].x = 0;
    } else if(positions.data[my_index].y > height) {
        positions.data[my_index].y = 0;
    } else if(positions.data[my_index].x < 0) {
        positions.data[my_index].x = width;
    } else if(positions.data[my_index].y < 0) {
        positions.data[my_index].y = height;
    }
}