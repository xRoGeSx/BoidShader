#[compute]
#version 450

#include "shared.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

void main() {

    uint my_index = gl_GlobalInvocationID.x;
    float LIST_SIZE = parameters.data[0]; 

    if(positions.data[my_index].x == -1) return;
    if(my_index > LIST_SIZE) return;
    
	float IMAGE_SIZE = parameters.data[1]; 
	float friend_radius = parameters.data[2];
	float avoid_radius = parameters.data[3];
	float min_vel = parameters.data[4]; 
	float max_vel = parameters.data[5];
	float alignment_factor = parameters.data[6];
	float cohesion_factor = parameters.data[7];
	float separation_factor = parameters.data[8];
	float width = parameters.data[9];
	float height = parameters.data[10];
	float delta = parameters.data[11];

    vec2 position = positions.data[my_index];
    vec2 velocity = velocities.data[my_index];
    vec2 target =  targets.data[0];
    
    vec2 cohesion = vec2(0,0);
    vec2 separation = vec2(0,0);
    vec2 alignment = vec2(0,0);

    int friends = 0;
    int avoids = 0;

    for(int i = 0; i < LIST_SIZE; i++) {
        if( my_index == i ) continue;

        vec2 otherPosition = positions.data[i];
        vec2 otherVelocity = velocities.data[i];

        float dist = distance(position, otherPosition);

        if(dist < friend_radius) {
            friends++;
            alignment+=otherVelocity;
            cohesion+=otherPosition;
            if(dist < avoid_radius) {
                avoids++;
                separation+= position - otherPosition;
            }
        }
       
        if(friends > 0) {
            velocity += normalize(alignment / friends) * alignment_factor ;
            velocity += normalize(cohesion / friends - position) * cohesion_factor ;
            
        }
        if(avoids > 0) {
            velocity += normalize(separation) * separation_factor ;
        }

       
    }

    float vel_magnitude = clamp(length(velocity), min_vel, max_vel);

    velocity = vel_magnitude * normalize(velocity);

    if(distance(position, target) < 325.0) {
        velocity += normalize(target - position) * 200.0;
    }

    position += velocity * delta;

    velocities.data[my_index].xy = velocity;
    positions.data[my_index].xy = position;


    float rotation = 0.0;
    rotation = acos(dot(normalize(velocity),vec2(1,0)));
    if (isnan(rotation)){
        rotation = 0.0;
    } else if (velocity.y < 0){
        rotation = -rotation;
    }



    ivec2 pixel_pos = ivec2(int(mod(my_index, IMAGE_SIZE)), int(my_index / IMAGE_SIZE));
    imageStore(
        boid_texture,
        pixel_pos,
        vec4(position.x, position.y, rotation, 0)
    );

    if(positions.data[my_index].x > width) {
        positions.data[my_index].x = 0;
    } else if (positions.data[my_index].y > height) {
        positions.data[my_index].y = 0;
    } else if (positions.data[my_index].x < 0) {
        positions.data[my_index].x = width;
    } else if (positions.data[my_index].y < 0) {
        positions.data[my_index].y = height;
    }
}