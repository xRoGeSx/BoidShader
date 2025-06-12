extends Node2D


const LIST_SIZE = 50;
const MAX_POLYGON_VERTICES = 200;

var rd := RenderingServer.get_rendering_device()
const MOUSE_ACTION = "MouseButtonLeft"

@onready var particle: GPUParticles2D = $BoidParticle

@onready var polygon = $Polygon2D
@onready var polygons = $Polygons


var run_boids_shader_file := load("res://src/shaders/run_boids.glsl")
var run_boids_shader_spirv: RDShaderSPIRV = run_boids_shader_file.get_spirv()
var run_boids_shader := rd.shader_create_from_spirv(run_boids_shader_spirv)
var pipeline_run_boids := rd.compute_pipeline_create(run_boids_shader)

var generate_bin_shader_file := load("res://src/shaders/generate_bin.glsl")
var generate_bin_shader_spirv: RDShaderSPIRV = generate_bin_shader_file.get_spirv()
var generate_bin_shader := rd.shader_create_from_spirv(generate_bin_shader_spirv)
var pipeline_generate_bin := rd.compute_pipeline_create(generate_bin_shader)

var generate_bin_sum_shader_file := load("res://src/shaders/generate_bin_sum.glsl")
var generate_bin_sum_shader_spirv: RDShaderSPIRV = generate_bin_sum_shader_file.get_spirv()
var generate_bin_sum_shader := rd.shader_create_from_spirv(generate_bin_sum_shader_spirv)
var pipeline_generate_bin_sum := rd.compute_pipeline_create(generate_bin_sum_shader)

var generate_bin_lookup_shader_file := load("res://src/shaders/generate_bin_lookup.glsl")
var generate_bin_lookup_shader_spirv: RDShaderSPIRV = generate_bin_lookup_shader_file.get_spirv()
var generate_bin_lookup_shader := rd.shader_create_from_spirv(generate_bin_lookup_shader_spirv)
var pipeline_generate_bin_lookup := rd.compute_pipeline_create(generate_bin_lookup_shader)

var generate_boid_lookup_shader_file := load("res://src/shaders/generate_bin_boid_lookup.glsl")
var generate_boid_lookup_shader_spirv: RDShaderSPIRV = generate_boid_lookup_shader_file.get_spirv()
var generate_boid_lookup_shader := rd.shader_create_from_spirv(generate_boid_lookup_shader_spirv)
var pipeline_generate_boid_lookup := rd.compute_pipeline_create(generate_boid_lookup_shader)

var process_polygons_shader_file := load("res://src/shaders/process_polygons.glsl")
var process_polygons_shader_spirv: RDShaderSPIRV = process_polygons_shader_file.get_spirv()
var process_polygons_shader := rd.shader_create_from_spirv(process_polygons_shader_spirv)
var pipeline_process_polygons := rd.compute_pipeline_create(process_polygons_shader)


var create_heatmap_shader_file := load("res://src/shaders/generate_boid_heatmap.glsl")
var create_heatmap_shader_spirv: RDShaderSPIRV = create_heatmap_shader_file.get_spirv()
var create_heatmap_shader := rd.shader_create_from_spirv(create_heatmap_shader_spirv)
var pipeline_create_heatmap := rd.compute_pipeline_create(create_heatmap_shader)

var position_buffer: RID
var position_uniform: RDUniform

var velocity_buffer: RID
var velocity_uniform: RDUniform

var param_buffer: RID
var param_uniform: RDUniform

var target_buffer: RID
var target_uniform: RDUniform


var boid_data: Image
var boid_data_texture: ImageTexture
var boid_data_texture_rd = Texture2DRD
var boid_data_texture_buffer: RID
var boid_data_texture_uniform: RDUniform

var heatmap: Image
var heatmap_texture: ImageTexture
var heatmap_texture_rd = Texture2DRD
var heatmap_texture_buffer: RID
var heatmap_texture_uniform: RDUniform

var bin_param_buffer: RID
var bin_param_uniform: RDUniform

var bin_buffer: RID
var bin_uniform: RDUniform

var bin_sum_buffer: RID
var bin_sum_uniform: RDUniform

var bin_index_lookup_buffer: RID
var bin_index_lookup_uniform: RDUniform

var bin_index_lookup_track_buffer: RID
var bin_index_lookup_track_uniform: RDUniform

var bin_boid_index_lookup_buffer: RID
var bin_boid_index_lookup_uniform: RDUniform

var boid_heatmap_buffer: RID
var boid_heatmap_uniform: RDUniform

var polygon_vertex_buffer: RID
var polygon_vertex_uniform: RDUniform

var polygon_vertex_lookup_buffer: RID
var polygon_vertex_lookup_uniform: RDUniform;


var inital_position: Array[Vector2] = []
var initial_velocity: Array[Vector2] = []
var initial_verticies: Array[Vector2] = []
var initial_lookup: Array[int] = []

var bin: Array[int] = []
var binSum: Array[int] = []
var binLookup: Array[int] = []
var binLookupTrack: Array[int] = []
var binIndexBoidLookup: Array[int] = []

var initial_heatmap: Array[int] = []


var shared_boid_uniform: RID
var shared_polygon_uniform: RID
var shared_heatmap_uniform: RID


var width = 400
var height = 200

@export_category("Boid Settings")
@export_range(0, 50) var friend_radius = 10.0
@export_range(0, 50) var avoid_radius = 5.0
@export_range(0, 100) var min_vel = 50.0
@export_range(0, 500) var max_vel = 75.0
@export_range(0, 100) var alignment_factor = 10.0
@export_range(0, 100) var cohesion_factor = 1.0
@export_range(0, 100) var separation_factor = 20.0
@export var PREFILL = true;
@export var RENDER_BIN = true;

@export var bin_size = 256;

var bin_amount_horizontal = ceil(get_viewport_rect().size.x / bin_size)
var bin_amount_vertical = ceil(get_viewport_rect().size.y / bin_size)

var bin_amount = bin_amount_horizontal * bin_amount_vertical


var IMAGE_SIZE = int(ceil((sqrt(LIST_SIZE))));

var shaderFloatRDL: float;

func getVec2ArrayFromShader(buffer: RID) -> Array[Vector2]:
	var output_bytes := rd.buffer_get_data(buffer)
	var output := output_bytes.to_float32_array()
	var outputVec2: Array[Vector2] = []
	outputVec2.resize(output.size() / 2)
	for index in outputVec2.size():
		var bufferIndex = index * 2
		outputVec2[index] = Vector2(output[bufferIndex], output[bufferIndex + 1])
	return outputVec2

func vec2ToBuffer(data: Array[Vector2]):
	var data_buffer_bytes := PackedVector2Array(data).to_byte_array()
	var data_buffer = rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)
	return data_buffer
func floatToBuffer(data: Array):
	var data_buffer_bytes := PackedFloat32Array(data).to_byte_array()
	var data_buffer = rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)
	return data_buffer
func intToBuffer(data: Array[int]):
	var data_buffer_bytes = PackedInt32Array(data).to_byte_array()
	var data_buffer = rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)
	return data_buffer
func createUniformFromBuffer(
	buffer_: RID,
	binding_: int,
	uniformType: RenderingDevice.UniformType = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER):
	var uniform_ := RDUniform.new()
	uniform_.uniform_type = uniformType
	uniform_.binding = binding_
	uniform_.add_id(buffer_)
	return uniform_


func floatArrayToPackedBytes(array) -> PackedByteArray:
	var input_ := PackedFloat32Array(array)
	return input_.to_byte_array()
func intArrayToPackedBytes(array) -> PackedByteArray:
	var input_ := PackedInt32Array(array)
	return input_.to_byte_array()
func vec2ArrayToPackedBytes(array) -> PackedByteArray:
	var input_ := PackedVector2Array(array)
	return input_.to_byte_array()


func createBufferFromArray(array: Array[int]):
	var input_bytes = floatArrayToPackedBytes(array)
	var buffer_ := rd.storage_buffer_create(input_bytes.size(), input_bytes)
	return buffer_
	

func generate_parameter_buffer(delta):
	return [
		LIST_SIZE,
		IMAGE_SIZE,
		friend_radius,
		avoid_radius,
		min_vel,
		max_vel,
		alignment_factor,
		cohesion_factor,
		separation_factor,
		get_viewport_rect().size.x,
		get_viewport_rect().size.y,
		delta
	]
	

func updateParamBuffer(buffer_: RID, delta: float):
	var updatedBuffer = floatArrayToPackedBytes(generate_parameter_buffer(delta))
	return rd.buffer_update(buffer_, 0, updatedBuffer.size(), updatedBuffer)
	
func generate_polygon_buffers():
	var lookup: Array[int] = [];
	var verticies: Array[Vector2] = [];
	lookup.resize(MAX_POLYGON_VERTICES)
	verticies.resize(MAX_POLYGON_VERTICES)
	var verticiesPassed = 0;
	var polyIndex = 0;
	for poly in polygons.get_children():
		for i in poly.polygon.size():
			verticies[verticiesPassed] = (poly.polygon[i] * poly.scale) + poly.position;
			verticiesPassed += 1;
		lookup[polyIndex] = poly.polygon.size() if polyIndex == 0 else lookup[polyIndex - 1] + poly.polygon.size();
		polyIndex += 1;
	return [verticies, lookup]


func updatePolygonBuffers():
	var g = generate_polygon_buffers()
	var verticies = vec2ArrayToPackedBytes(g[0]);
	var lookup = intArrayToPackedBytes(g[1])
	
	rd.buffer_update(polygon_vertex_buffer, 0, verticies.size(), verticies)
	rd.buffer_update(polygon_vertex_lookup_buffer, 0, lookup.size(), lookup)


func addValueToBuffer(buffer_: RID, value):
	var array = rd.buffer_get_data(buffer_).to_float32_array()
	var firstEmptyValueIndex = array.find(-1)
	if firstEmptyValueIndex == -1: return

	if (typeof(value) != TYPE_ARRAY):
		#print("Add non array")
		array.remove_at(firstEmptyValueIndex)
		array.remove_at(firstEmptyValueIndex)
		array.insert(firstEmptyValueIndex, value.x)
		array.insert(firstEmptyValueIndex + 1, value.y)
	if (typeof(value) == TYPE_ARRAY):
		for element in value:
			firstEmptyValueIndex = array.find(-1)
			if firstEmptyValueIndex == -1:
				break ;
			array.remove_at(firstEmptyValueIndex)
			array.remove_at(firstEmptyValueIndex)
			array.insert(firstEmptyValueIndex, element.x)
			array.insert(firstEmptyValueIndex + 1, element.y)
	var packedBytes = floatArrayToPackedBytes(array)
	rd.buffer_update(buffer_, 0, packedBytes.size(), packedBytes)


func removeLastValueFromBuffer(buffer_: RID):
	var array = rd.buffer_get_data(buffer_).to_float32_array()
	var firstEmptyValueIndex = array.find(-1)
	if firstEmptyValueIndex == 0: return

	var size = array.size()
	
	if firstEmptyValueIndex == -1:
		firstEmptyValueIndex = array.size()

	array.set(firstEmptyValueIndex - 1, -1)
	array.set(firstEmptyValueIndex - 2, -1)
	var packedBytes = floatArrayToPackedBytes(array)
	rd.buffer_update(buffer_, 0, packedBytes.size(), packedBytes)

func replaceValueInBuffer(buffer_: RID, index: int, value: int):
	var array = rd.buffer_get_data(buffer_).to_float32_array()
	array.remove_at(index)
	array.insert(index, value)
	var packedBytes = floatArrayToPackedBytes(array)
	rd.buffer_update(buffer_, 0, packedBytes.size(), packedBytes)


func setupComputeShader():
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH)
	heatmap = Image.create(get_viewport_rect().size.x, get_viewport_rect().size.y, false, Image.FORMAT_RGBAH)
			
	$BoidParticle.amount = LIST_SIZE

	var format_boid_data := RDTextureFormat.new()
	format_boid_data.width = IMAGE_SIZE
	format_boid_data.height = IMAGE_SIZE
	format_boid_data.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format_boid_data.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	

	var format_heatmap := RDTextureFormat.new()
	format_heatmap.width = get_viewport_rect().size.x
	format_heatmap.height = get_viewport_rect().size.y
	format_heatmap.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format_heatmap.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	var params = generate_parameter_buffer(1)

	boid_data_texture_buffer = rd.texture_create(format_boid_data, RDTextureView.new(), boid_data.get_data())
	boid_data_texture_rd.texture_rd_rid = boid_data_texture_buffer

	heatmap_texture_buffer = rd.texture_create(format_heatmap, RDTextureView.new(), heatmap.get_data())
	heatmap_texture_rd.texture_rd_rid = heatmap_texture_buffer
	
	position_buffer = vec2ToBuffer(inital_position)
	velocity_buffer = vec2ToBuffer(initial_velocity)
	param_buffer = floatToBuffer(params)
	target_buffer = vec2ToBuffer(([Vector2(-1, -1)]))
	bin_param_buffer = intToBuffer([bin_size, getBinAmount()])
	bin_buffer = intToBuffer(bin)
	bin_sum_buffer = intToBuffer(binSum)
	bin_index_lookup_buffer = intToBuffer(binLookup)
	bin_index_lookup_track_buffer = intToBuffer(binLookupTrack)
	bin_boid_index_lookup_buffer = intToBuffer(binIndexBoidLookup)

	polygon_vertex_buffer = vec2ToBuffer(initial_verticies)
	polygon_vertex_lookup_buffer = intToBuffer(initial_lookup)

	boid_heatmap_buffer = intToBuffer(initial_heatmap)


	position_uniform = createUniformFromBuffer(position_buffer, 0)
	velocity_uniform = createUniformFromBuffer(velocity_buffer, 1)
	param_uniform = createUniformFromBuffer(param_buffer, 2)
	target_uniform = createUniformFromBuffer(target_buffer, 3)
	boid_data_texture_uniform = createUniformFromBuffer(boid_data_texture_buffer, 4, RenderingDevice.UNIFORM_TYPE_IMAGE)
	bin_param_uniform = createUniformFromBuffer(bin_param_buffer, 5)
	bin_uniform = createUniformFromBuffer(bin_buffer, 6)
	bin_sum_uniform = createUniformFromBuffer(bin_sum_buffer, 7)
	bin_index_lookup_uniform = createUniformFromBuffer(bin_index_lookup_buffer, 8)
	bin_index_lookup_track_uniform = createUniformFromBuffer(bin_index_lookup_track_buffer, 9)
	bin_boid_index_lookup_uniform = createUniformFromBuffer(bin_boid_index_lookup_buffer, 10)

	polygon_vertex_uniform = createUniformFromBuffer(polygon_vertex_buffer, 0)
	polygon_vertex_lookup_uniform = createUniformFromBuffer(polygon_vertex_lookup_buffer, 1)
	
	boid_heatmap_uniform = createUniformFromBuffer(boid_heatmap_buffer, 0)
	heatmap_texture_uniform = createUniformFromBuffer(heatmap_texture_buffer, 1, RenderingDevice.UNIFORM_TYPE_IMAGE)

	shared_boid_uniform = rd.uniform_set_create([
		position_uniform,
		velocity_uniform,
		param_uniform,
		target_uniform,
		boid_data_texture_uniform,
		bin_param_uniform,
		bin_uniform,
		bin_sum_uniform,
		bin_index_lookup_uniform,
		bin_index_lookup_track_uniform,
		bin_boid_index_lookup_uniform,
	], run_boids_shader, 0)

	shared_polygon_uniform = rd.uniform_set_create([
		polygon_vertex_uniform,
		polygon_vertex_lookup_uniform
	], process_polygons_shader, 1)

	shared_heatmap_uniform = rd.uniform_set_create([
		boid_heatmap_uniform,
		heatmap_texture_uniform
	], create_heatmap_shader, 2)
	
	pass


func raycast(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2):
	var x1: float = a1.x
	var x2: float = a2.x
	var x3: float = b1.x
	var x4: float = b2.x
	var y1: float = a1.y
	var y2: float = a2.y
	var y3: float = b1.y
	var y4: float = b2.y

	var denominator = ((y4 - y3) * (x2 - x1)) - ((x4 - x3) * (y2 - y1))
	if (denominator == 0): return ;

	var ua = (((x4 - x3) * (y1 - y3)) - ((y4 - y3) * (x1 - x3))) / denominator
	var ub = (((x2 - x1) * (y1 - y3)) - ((y2 - y1) * (x1 - x3))) / denominator

	var x = x1 + ua * (x2 - x1)
	var y = y1 + ub * (y2 - y1)

	return Vector2(x, y)


func raycast2(a: Vector2, b: Vector2, c: Vector2, d: Vector2):
	var r = b - a;
	var s = d - c;

	var d_ = r.x * s.y - r.y * s.x;
	var u_ = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / d_;
	var t_ = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / d_;

	if (u_ <= 0 || u_ >= 1): return ;
	if (t_ <= 0 || t_ >= 1): return ;
	return a + t_ * r
	
func lineIntersect(a, b, c, d):
	var r = b - a;
	var s = d - c;
	var d_ = r.x * s.y - r.y * s.x;
	var u = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / d_;
	var t = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / d_;
	if (0 <= u && u <= 1 && 0 <= t && t <= 1): return ;
	return a + t * r;

func rotateVector(along: Vector2, vector: Vector2, degrees: float):
	var originPosition = vector - along;
	var x2 = cos(degrees) * originPosition.x - sin(degrees) * originPosition.y;
	var y2 = sin(degrees) * originPosition.x + cos(degrees) * originPosition.y
	return Vector2(x2, y2) + along

func drawPolygonIntersection():
	var _polygon = polygons.get_children()[0]
	var end = get_global_mouse_position()
	var start = _polygon.position;
	draw_line(start, end, Color.RED, 1, true)
	var arc = PI / 8;
	draw_line(start, rotateVector(start, end, arc), Color.RED, 1, true)
	draw_line(start, rotateVector(start, end, -arc), Color.RED, 1, true)
	var size = initial_lookup[0];
	for index in size:
		var cur = initial_verticies[index];
		var next = initial_verticies[0 if index == size - 1 else index + 1]
		
		
		var intersection = raycast2(cur, next, start, end)
		var intersection2 = raycast2(cur, next, start, rotateVector(start, end, arc))
		var intersection3 = raycast2(cur, next, start, rotateVector(start, end, -arc))
		draw_line(cur, next, Color.RED, 1, true)
		if (intersection):
			draw_circle(intersection, 4.0, Color.BLUE)
		if (intersection2):
			draw_circle(intersection2, 4.0, Color.BLUE)
		if (intersection3):
			draw_circle(intersection3, 4.0, Color.BLUE)
		

func _draw():
	#drawPolygonIntersection()
	if (!RENDER_BIN): return ;
	for x in bin_amount_horizontal:
		for y in bin_amount_vertical:
			draw_rect(
				Rect2(x * bin_size,
						  y * bin_size,
					  bin_size,
					  bin_size
					  ),
				Color(255, 0, 0), false, 1)
			draw_string(ThemeDB.fallback_font, Vector2(x * bin_size + 12, y * bin_size + 22), str(x + y * bin_amount_horizontal))


func logArrayAsTable(array: Array[PackedInt32Array], name_: String):
	if (name_): print(name_)
	for i in bin_amount_vertical:
		var row = [];
		for j in bin_amount_horizontal:
			var index = i * bin_amount_horizontal + j;
			row.push_back(array[index])
		print(row)
			

func _physics_process(delta):
	if (Input.is_key_pressed(KEY_Q)):
		return ;
	updateParamBuffer(param_buffer, delta)
	updatePolygonBuffers()
	
	removeLastValueFromBuffer(target_buffer)
	addValueToBuffer(target_buffer, get_global_mouse_position())

	
	_run_compute_shader(pipeline_generate_bin)
	_run_compute_shader(pipeline_generate_bin_sum)
	_run_compute_shader(pipeline_generate_bin_lookup)
	_run_compute_shader(pipeline_generate_boid_lookup)
	_run_compute_shader(pipeline_run_boids)
	_run_compute_shader_screen(pipeline_create_heatmap)

	_run_compute_shader(pipeline_process_polygons)

func _process(delta):
	queue_redraw()
	bin_amount_horizontal = ceil(get_viewport_rect().size.x / bin_size)
	bin_amount_vertical = ceil(get_viewport_rect().size.y / bin_size)
	
	get_window().title = " / Boids: " + str(LIST_SIZE) + " / FPS: " + str(Engine.get_frames_per_second())
	
	if (Input.is_key_pressed(KEY_W)):
		remove_child(polygon)
		removeLastValueFromBuffer(polygon_vertex_lookup_buffer)
	if (Input.is_action_pressed((MOUSE_ACTION))):
		addBoid(get_viewport().get_mouse_position(), 1)
	if (Input.is_key_pressed(KEY_Q)):
		return ;
	var b = rd.buffer_get_data(bin_buffer).to_int32_array()
	var bss = rd.buffer_get_data(bin_sum_buffer).to_int32_array()
	var ss = rd.buffer_get_data(bin_index_lookup_buffer).to_int32_array()
	var bs = rd.buffer_get_data(bin_boid_index_lookup_buffer).to_int32_array()
	
	print("Bin sum \n", bss)
	print("Bin \n", b)
	print("Bin lookup\n", ss)
	print("Bin boid lookup\n", bs)
	print(ss)
	# var heatmap = rd.buffer_get_data(boid_heatmap_buffer).to_int32_array();
	# print(heatmap.slice(10000, 10002))
	# $CanvasLayer/ColorRect.material.set_shader_parameter("boid_heatmap", heatmap)

	#var polyv = getVec2ArrayFromShader(polygon_vertex_buffer);
	#print(polyv)
	#print(poly)

	
func _run_compute_shader(pipeline):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, shared_boid_uniform, 0)
	rd.compute_list_bind_uniform_set(compute_list, shared_polygon_uniform, 1)
	rd.compute_list_bind_uniform_set(compute_list, shared_heatmap_uniform, 2)
	rd.compute_list_dispatch(compute_list, round(LIST_SIZE / 1024 + 1), 1, 1)
	rd.compute_list_end()
	
func _run_compute_shader_screen(pipeline):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, shared_boid_uniform, 0)
	rd.compute_list_bind_uniform_set(compute_list, shared_polygon_uniform, 1)
	rd.compute_list_bind_uniform_set(compute_list, shared_heatmap_uniform, 2)
	rd.compute_list_dispatch(compute_list, get_viewport_rect().size.x / 32, get_viewport_rect().size.y / 32, 1)
	rd.compute_list_end()

func addBoid(position_: Vector2, amount: int = 1):
	if (amount == 1):
		addValueToBuffer(velocity_buffer, Vector2(1, 1))
		addValueToBuffer(position_buffer, position_)
		return ;
	var positions = []
	var velocities = []
	positions.resize(amount)
	velocities.resize(amount)
	for i in amount:
		var modify_position = Vector2(randf_range(0, 20), randf_range(0, 20))
		var modify_velocity = Vector2(randf_range(0, 20), randf_range(0, 20))
		positions[i] = position_ + modify_position
		velocities[i] = modify_velocity;
	addValueToBuffer(velocity_buffer, velocities)
	addValueToBuffer(position_buffer, positions)
	

func getBinAmount():
	var x = get_viewport_rect().size.x
	var y = get_viewport_rect().size.y
	return ceil(x / bin_size) * ceil(y / bin_size) * 6

func _ready():
	inital_position.resize(LIST_SIZE)
	initial_velocity.resize(LIST_SIZE)
	if (PREFILL):
		for i in LIST_SIZE:
			inital_position[i] = Vector2(
				randf() * get_viewport_rect().size.x,
				randf() * get_viewport_rect().size.y
			)
			initial_velocity[i] = Vector2(randf(), randf())
	else:
		for i in LIST_SIZE:
			inital_position[i] = Vector2(
				-1, -1
			)
			initial_velocity[i] = Vector2(
				-1, -1
			)
	
	bin.resize(LIST_SIZE)
	bin.fill(0)
	binSum.resize(getBinAmount())
	binSum.fill(0)
	binLookup.resize(getBinAmount())
	binLookup.fill(0)
	binLookupTrack.resize(getBinAmount())
	binLookupTrack.fill(0)
	binIndexBoidLookup.resize(LIST_SIZE)
	binIndexBoidLookup.fill(0)
	initial_lookup.resize(MAX_POLYGON_VERTICES)
	initial_verticies.resize(MAX_POLYGON_VERTICES)
	initial_heatmap.resize(get_viewport_rect().size.x * get_viewport_rect().size.y)
	initial_heatmap.fill(0)
	
	bin_amount_horizontal = ceil(get_viewport_rect().size.x / bin_size)
	bin_amount_vertical = ceil(get_viewport_rect().size.y / bin_size)
	
	var verticiesPassed = 0;
	var polyIndex = 0;
	for poly in polygons.get_children():
		for i in poly.polygon.size():
			initial_verticies[verticiesPassed] = (poly.polygon[i] * poly.scale) + poly.position;
			verticiesPassed += 1;
		initial_lookup[polyIndex] = poly.polygon.size() if polyIndex == 0 else initial_lookup[polyIndex - 1] + poly.polygon.size();
		polyIndex += 1;
		
	
	boid_data_texture_rd = $BoidParticle.process_material.get_shader_parameter("boid_data")
	heatmap_texture_rd = $CanvasLayer/ColorRect.material.get_shader_parameter("heatmap")
	
	RenderingServer.call_on_render_thread(setupComputeShader)


func _on_shape_spawner__on_item_selected(polygon_: Polygon2D):
	polygon_.position = get_global_mouse_position()
	polygons.add_child(polygon_.duplicate())
	updatePolygonBuffers()
	pass # Replace with function body.
