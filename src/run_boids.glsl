#[compute]
#version 450

#include "shared.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

float velocityToRotation(vec2 vel) {
    float rotation = 0.0;
    rotation = acos(dot(normalize(vel), vec2(1, 0)));
    if(isnan(rotation)) {
        rotation = 0.0;
    } else if(vel.y < 0) {
        rotation = -rotation;
    }
    return rotation;
}

vec2 calculateNormal(vec2 edgeStart, vec2 edgeEnd, vec2 point) {
    vec2 lineDir = edgeEnd - edgeStart;
    vec2 perpDir = vec2(lineDir.y, -lineDir.x);
    vec2 dirToedgeStart = edgeStart - point;
    return perpDir;
}

float DistToLine(vec2 edgeStart, vec2 edgeEnd, vec2 point) {
    vec2 lineDir = edgeEnd - edgeStart;
    vec2 perpDir = vec2(lineDir.y, -lineDir.x);
    vec2 dirToedgeStart = edgeStart - point;
    return abs(dot(normalize(perpDir), dirToedgeStart));
}

vec2 raycast(vec2 a1, vec2 a2, vec2 b1, vec2 b2) {
    float denominator = ((b2.y - b1.y) * (a2.x - a1.x)) - ((b2.x - b1.x) * (a2.y - a1.y));
    if(denominator == 0)
        return vec2(0, 0);

    float ua = (((b2.x - b1.x) * (a1.y - b1.y)) - ((b2.y - b1.y) * (a1.x - b1.x))) / denominator;
    float ub = (((a2.x - a1.x) * (a1.y - b1.y)) - ((a2.y - a1.y) * (a1.x - b1.x))) / denominator;

    float x = a1.x + ua * (a2.x - a1.x);
    float y = a1.y + ub * (a2.y - a1.y);

    return vec2(x, y);
}

int getBinIndex(vec2 position) {
    float width = parameters.data[9];

    int bin_size = binParameters.size;
    int horizontal_bin_amount = int(ceil(width / bin_size));

    int my_bin = int(position.x / (bin_size)) + int(position.y / (bin_size)) * horizontal_bin_amount;
    return my_bin;
}

void getNeighbouringBins(int binIndex, inout int neighbours[9]) {
    float width = parameters.data[9];
    float bin_amount = binParameters.amount;
    int bin_size = binParameters.size;
    int horizontal_bin_amount = int(ceil(width / bin_size));

    int iteration = 0;
    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            iteration++;
            int neighbour_bin_index = binIndex + x + y * horizontal_bin_amount;
            if(neighbour_bin_index < 0 || neighbour_bin_index > bin_amount) {
                neighbours[iteration] = -1;
                continue;
            }
            neighbours[iteration] = neighbour_bin_index;

        }
    }
}

void processBoidCollision(int my_index, inout vec2 result[4]) {

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

    int my_bin = getBinIndex(position);

    int[9] neighbourBins = int[](-1, -1, -1, -1, -1, -1, -1, -1, -1);
    getNeighbouringBins(my_bin, neighbourBins);

    for(int neighbour_bin_index_lookup = 0; neighbour_bin_index_lookup < neighbourBins.length(); neighbour_bin_index_lookup++) {

        int neighbour_bin_index = neighbourBins[neighbour_bin_index_lookup];
        if(neighbour_bin_index == -1)
            continue;

        int bin_lookup_end = binIndexTackLookup.data[neighbour_bin_index];
        int bin_lookup_start = binIndexTackLookup.data[neighbour_bin_index == 0 ? 0 : neighbour_bin_index - 1];

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
                // if(watching_index == my_index) {
                //     ivec2 pixel_pos = ivec2(int(mod(i, IMAGE_SIZE)), int(i / IMAGE_SIZE));
                //     vec4 previous_pixel = imageLoad(boid_texture, pixel_pos);
                //     imageStore(boid_texture, pixel_pos, vec4(previous_pixel.r, previous_pixel.g, previous_pixel.b, detection));
                // }

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

    for(int i = 0; i < polygonVerticiesLookup.data[polygon_index]; i++) {
        verticies++;
        polygonCenter += polygonVerticies.data[i];
        continue;
    }
    polygonCenter /= verticies;

    float separation_factor_mod = 1.0;
    if(distance(polygonCenter, position) < 200) {

        /* Point is in polygon attraction  range */
        /* Check if the point is inside polygon */
        int numberOfIntersections = 0;
        int currentPolygon = polygonVerticiesLookup.data[polygon_index];
        for(int i = 0; i < currentPolygon; i++) {
            vec2 ray = position;
            vec2 edgeStart = polygonVerticies.data[i];
            vec2 edgeEnd = polygonVerticies.data[i == currentPolygon - 1 ? 0 : i + 1];

            if(ray.y > edgeStart.y && ray.y > edgeEnd.y)
                continue;
            if(ray.y < edgeStart.y && ray.y < edgeEnd.y)
                continue;
            if(ray.x < edgeStart.x + ((ray.y - edgeStart.y) / (edgeEnd.y - edgeStart.y)) * (edgeEnd.x - edgeStart.x))
                numberOfIntersections++;
            continue;
        }
        if(numberOfIntersections % 2 != 0) {
            separation_factor_mod *= 4;
            velocity += normalize(polygonCenter - position) * -.5;
            for(int i = 0; i < currentPolygon; i++) {
                vec2 ray = position;
                vec2 rayEnd = position + velocity * 100;
                vec2 edgeStart = polygonVerticies.data[i];
                vec2 edgeEnd = polygonVerticies.data[i == currentPolygon - 1 ? 0 : i + 1];
                vec2 intersection = raycast(edgeStart, edgeEnd, ray, rayEnd);
                float distanceToEdge = length(position - intersection);
                if(distanceToEdge < 20) {
                    detection_type = 5;
                    velocity += normalize(position - intersection) * 50.0;
                } else {

                }
                continue;
            }

        /* Is inside polygon */
        } else {
            velocity += normalize(polygonCenter - position) * 30.0;
        }
    }
    vec2 modVelocity = velocity - initialVelocity;
    return vec4(modVelocity.x, modVelocity.y, separation_factor_mod, 0.0);
}

void main() {

    uint my_index = gl_GlobalInvocationID.x;
    int watching_index = 0;

    float LIST_SIZE = parameters.data[0];

    if(positions.data[my_index].x == -1)
        return;
    if(my_index > LIST_SIZE)
        return;

    float IMAGE_SIZE = parameters.data[1];
    ivec2 pixel_pos = ivec2(int(mod(my_index, IMAGE_SIZE)), int(my_index / IMAGE_SIZE));

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
    vec4 polygonCollisionResult = processPolygonCollision(0, int(my_index), detection_type);
    processBoidCollision(int(my_index), boidCollisionResult);

    vec2 cohesion = boidCollisionResult[0];
    vec2 separation = boidCollisionResult[1];
    vec2 alignment = boidCollisionResult[2];

    int friends = int(boidCollisionResult[3].x);
    int avoids = int(boidCollisionResult[3].y);

    velocity += polygonCollisionResult.xy;
    separation_factor *= polygonCollisionResult.z;

    if(friends > 0) {
        velocity += normalize(alignment / friends) * alignment_factor;
        velocity += normalize(cohesion / friends - position) * cohesion_factor;

    }
    if(avoids > 0) {
        velocity += normalize(separation) * separation_factor;
    }

    float vel_magnitude = clamp(length(velocity), min_vel, max_vel);
    velocity = vel_magnitude * normalize(velocity);

    if(distance(position, target) < 325.0) {
        velocity += normalize(target - position) * 50.0;
    }

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