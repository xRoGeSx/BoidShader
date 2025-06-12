float velocityToRotation(vec2 vel) {
    float rotation = 0.0;
    rotation = acos(dot(normalize(vel), vec2(1, 0)));
    if(isnan(rotation)) {
        rotation = 0.0;
    } else if(vel.y < 0.0) {
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

vec2 rotateVector(vec2 along, vec2 vector, float degrees) {
    vec2 originPosition = vector - along;
    float x2 = cos(degrees) * originPosition.x - sin(degrees) * originPosition.y;
    float y2 = sin(degrees) * originPosition.x + cos(degrees) * originPosition.y;
    return vec2(x2, y2) + along;
}

vec2 raycast(vec2 a, vec2 b, vec2 c, vec2 d) {
    vec2 r = b - a;
    vec2 s = d - c;

    float d_ = r.x * s.y - r.y * s.x;
    float u_ = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / d_;
    float t_ = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / d_;

    if(u_ <= 0 || u_ >= 1)
        return vec2(0, 0);
    if(t_ <= 0 || t_ >= 1)
        return vec2(0, 02);
    return a + t_ * r;
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
    int bin_amount = int(binParameters.amount);
    int bin_size = binParameters.size;
    int horizontal_bin_amount = int(ceil(width / bin_size));
    bool isLeftEdge = binIndex % horizontal_bin_amount == 0;
    bool isRightEdge = binIndex == horizontal_bin_amount;
    bool isTopEdge = bin_size < bin_amount;
    bool isBottomEdge = (bin_amount - binIndex) < horizontal_bin_amount;

    int iteration = 0;
    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            int neighbour_bin_index = binIndex + x + y * horizontal_bin_amount;
            if(neighbour_bin_index < 0 || neighbour_bin_index > bin_amount) {
                neighbours[iteration] = -1;
                continue;
            }
            neighbours[iteration] = neighbour_bin_index;
            iteration++;
        }
    }
}
