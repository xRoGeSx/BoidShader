#define M_PI 3.1415926535897932384626433832795

layout(set = 0, binding = 0, std430) restrict buffer PositionBuffer {
vec2 data[];
}
positions;

layout(set = 0, binding = 1, std430) restrict buffer VelocityBuffer {
vec2 data[];
}
velocities;

layout(set = 0, binding = 2, std430) restrict buffer ParameterBuffer {
float data[];
}
parameters;

layout(set = 0, binding = 3, std430) restrict buffer TargetsBuffer {
vec2 data[];
}
targets;

layout(set = 0, binding = 4, rgba16f) uniform image2D boid_texture;

layout(set = 0, binding = 5, std430) restrict buffer BinParameters {
int size;
int amount;
}
binParameters;

layout(set = 0, binding = 6, std430) restrict buffer Bin {
int data[];
}
bin;

layout(set = 0, binding = 7, std430) restrict buffer BinSum {
int data[];
}
binSum;

layout(set = 0, binding = 8, std430) restrict buffer BinIndexLookup {
int data[];
}
binIndexLookup;

layout(set = 0, binding = 9, std430) restrict buffer BinIndexTrackLookup {
int data[];
}
binIndexTackLookup;

layout(set = 0, binding = 10, std430) restrict buffer BinBoidLookup {
int data[];
}
binBoidLookups;

layout(set = 1, binding = 0, std430) restrict buffer PolygonVerticies {
vec2 data[];
}
polygonVerticies;
layout(set = 1, binding = 1, std430) restrict buffer PolygonVerticiesLookup {
int data[];
}
polygonVerticiesLookup;

layout(set = 2, binding = 0, std430) restrict buffer BoidHeatmap {
int data[];
}
boidHeatmap;

layout(set = 2, binding = 1, rgba16f) uniform image2D heatmap_texture;
