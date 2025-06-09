extends Polygon2D

@onready var collision_polygon_2d = $Area2D/CollisionPolygon2D


var INITIAL_COLOR;
var HIGHLIGHTED_COLOR;

var highlighted = false;
var mouseStart;

const MOUSE_ACTION = "MouseButtonLeft"
const MOUSE_WHEEL_UP = "MouseWheelUp"
const MOUSE_WHEEL_DOWN = "MouseWheelDown"
# Called when the node enters the scene tree for the first time.
func _ready():
	collision_polygon_2d.polygon = polygon;
	INITIAL_COLOR = color;
	var modifiedColor = INITIAL_COLOR;
	modifiedColor.a = 1.0;
	HIGHLIGHTED_COLOR = modifiedColor;
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(Input.is_action_just_pressed(MOUSE_ACTION)):
		mouseStart = get_local_mouse_position()
	if(highlighted): 
		color = Color(255,0,0,0.2);
		if(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			position =  get_global_mouse_position() - mouseStart
		if(Input.is_action_just_released(MOUSE_WHEEL_UP)):
			scale += Vector2(2,2) * delta
		if(Input.is_action_just_released(MOUSE_WHEEL_DOWN)):
			scale -= Vector2(2,2)  * delta
	else:
		color = INITIAL_COLOR;
	pass


func _on_area_2d_mouse_entered():
	highlighted = true;
	pass # Replace with function body.


func _on_area_2d_mouse_exited():
	highlighted = false;
	pass # Replace with function body.
