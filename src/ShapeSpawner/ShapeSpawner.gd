class_name ShapeSpawner
extends Node2D
@onready var List: ItemList = $List
@onready var PolygonsNode: Node2D = $Polygons

signal _on_item_selected(polygon: Polygon2D)

var polygons = []

var show = false;
var currentItemSelection = null;
var recordInteraction = false;

const COTNEXT_MENU_ACTION = "ContextMenu"

# Called when the node enters the scene tree for the first time.
func _ready():
	PolygonsNode.hide()
	polygons = PolygonsNode.get_children() as Array[Polygon2D];
	for polygon in polygons:
		List.add_item(polygon.name, null, true)
	List.hide()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var listPosition = get_local_mouse_position() - List.position;
	if(recordInteraction):
		currentItemSelection = List.get_item_at_position(listPosition) ;

	if(Input.is_action_just_pressed(COTNEXT_MENU_ACTION)):
		currentItemSelection = null;
		List.position = get_global_mouse_position()
		List.show()
		
	if(Input.is_action_just_released(COTNEXT_MENU_ACTION)):
		List.hide()
		if(!recordInteraction): return;
		
	
	pass


func _on_list_item_selected(index):
	_on_item_selected.emit(polygons[index])
	List.hide()
	List.deselect_all()
	pass # Replace with function body.



func _on_list_mouse_entered():
	recordInteraction = true;
	pass # Replace with function body.


func _on_list_mouse_exited():
	if(Input.is_action_just_released(COTNEXT_MENU_ACTION)):
		_on_item_selected.emit(polygons[currentItemSelection])
	recordInteraction = false;
	currentItemSelection = null;
	pass # Replace with function body.
