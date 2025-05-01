#[compute]
#version 450

#include "shared.glsl"

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

 
float velocityToRotation(vec2 vel) {
    float rotation = 0.0;
    rotation = acos(dot(normalize(vel),vec2(1,0)));
    if (isnan(rotation)){
        rotation = 0.0;
    } else if (vel.y < 0){
        rotation = -rotation;
    }
    return rotation;
}

void main() {

    uint my_index = gl_GlobalInvocationID.x;
    int watching_index = 0;

    float LIST_SIZE = parameters.data[0]; 

    if(positions.data[my_index].x == -1) return;
    if(my_index > LIST_SIZE) return;
    
	float IMAGE_SIZE = parameters.data[1]; 
    ivec2 pixel_pos = ivec2(int(mod(my_index, IMAGE_SIZE)), int(my_index / IMAGE_SIZE));

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

    float bin_amount = binParameters.amount;
    int bin_size = binParameters.size;
    
    vec2 position = positions.data[my_index];
    vec2 velocity = velocities.data[my_index];
    vec2 target =  targets.data[0];
    
    vec2 cohesion = vec2(0,0);
    vec2 separation = vec2(0,0);
    vec2 alignment = vec2(0,0);

    int friends = 0;
    int avoids = 0;

    int horizontal_bin_amount = int(ceil(width / bin_size));

    int my_bin = 
       int(position.x / (bin_size)) 
     + int(position.y / (bin_size)) * horizontal_bin_amount;
     


    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            int neighbour_bin_index = my_bin + x + y * horizontal_bin_amount;
            if(neighbour_bin_index < 0 || neighbour_bin_index > bin_amount) continue;

             int bin_lookup_end = binIndexTackLookup.data[neighbour_bin_index];
             int bin_lookup_start = binIndexTackLookup.data[neighbour_bin_index == 0 ? 0 : neighbour_bin_index -1];


              for(int lookup_index = bin_lookup_start; lookup_index < bin_lookup_end -1; lookup_index++) {
                
                int i = binBoidLookups.data[lookup_index];
                int detection = 0;
                if( my_index == i ) continue;

                vec2 otherPosition = positions.data[i];
                vec2 otherVelocity = velocities.data[i];

                float dist = distance(position, otherPosition);

                if(dist < friend_radius) {
                    detection = 1;

                    friends++;
                    alignment+=otherVelocity;
                    cohesion+=otherPosition;
                    if(dist < avoid_radius) {
                        avoids++;
                        separation+= position - otherPosition;
                    }
                }
                if(watching_index == my_index) {
                    ivec2 pixel_pos = ivec2(int(mod(i, IMAGE_SIZE)), int(i / IMAGE_SIZE));
                    vec4 previous_pixel = imageLoad(boid_texture, pixel_pos);
                    imageStore(
                        boid_texture,
                        pixel_pos,
                        vec4(previous_pixel.r, previous_pixel.g, previous_pixel.b, detection)
                    );
                }

            }
        }
    }

  

      
    if(friends > 0) {
        velocity += normalize(alignment / friends) * alignment_factor ;
        velocity += normalize(cohesion / friends - position) * cohesion_factor ;
        
    }
    if(avoids > 0) {
        velocity += normalize(separation) * separation_factor ;
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


    vec4 old_texture_pixel = imageLoad(boid_texture, pixel_pos);
    int detection_type = int(old_texture_pixel.a);
    if(my_index == watching_index){
        detection_type = 4;
    }
    imageStore(boid_texture, pixel_pos, vec4(position.x, position.y, rotation, detection_type));


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