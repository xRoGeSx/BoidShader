class_name VectorUtils

func raycast2(a: Vector2, b: Vector2, c: Vector2, d: Vector2):
	var r = b - a;
	var s = d - c;

	var d_ = r.x * s.y - r.y * s.x;
	var u_ = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / d_;
	var t_ = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / d_;

	if (u_ <= 0 || u_ >= 1): return ;
	if (t_ <= 0 || t_ >= 1): return ;
	return a + t_ * r
	


func rotateVector(along: Vector2, vector: Vector2, degrees: float):
	var originPosition = vector - along;
	var x2 = cos(degrees) * originPosition.x - sin(degrees) * originPosition.y;
	var y2 = sin(degrees) * originPosition.x + cos(degrees) * originPosition.y
	return Vector2(x2, y2) + along
