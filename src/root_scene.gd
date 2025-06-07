extends Node2D


const LIST_SIZE = 20000;
const MAX_POLYGON_VERTICES = 20;

var rd := RenderingServer.get_rendering_device()
@onready var moving_boxes = $MovingBoxes
@onready var particle: GPUParticles2D = $BoidParticle
@onready var polygon = $Polygon2D

const box = preload("res://src/Box/Box.tscn")


var run_boids_shader_file := load("res://src/run_boids.glsl")
var run_boids_shader_spirv: RDShaderSPIRV = run_boids_shader_file.get_spirv()
var run_boids_shader := rd.shader_create_from_spirv(run_boids_shader_spirv)
var pipeline_run_boids := rd.compute_pipeline_create(run_boids_shader)

var generate_bin_shader_file := load("res://src/generate_bin.glsl")
var generate_bin_shader_spirv: RDShaderSPIRV = generate_bin_shader_file.get_spirv()
var generate_bin_shader := rd.shader_create_from_spirv(generate_bin_shader_spirv)
var pipeline_generate_bin := rd.compute_pipeline_create(generate_bin_shader)

var generate_bin_sum_shader_file := load("res://src/generate_bin_sum.glsl")
var generate_bin_sum_shader_spirv: RDShaderSPIRV = generate_bin_sum_shader_file.get_spirv()
var generate_bin_sum_shader := rd.shader_create_from_spirv(generate_bin_sum_shader_spirv)
var pipeline_generate_bin_sum := rd.compute_pipeline_create(generate_bin_sum_shader)

var generate_bin_lookup_shader_file := load("res://src/generate_bin_lookup.glsl")
var generate_bin_lookup_shader_spirv: RDShaderSPIRV = generate_bin_lookup_shader_file.get_spirv()
var generate_bin_lookup_shader := rd.shader_create_from_spirv(generate_bin_lookup_shader_spirv)
var pipeline_generate_bin_lookup := rd.compute_pipeline_create(generate_bin_lookup_shader)

var generate_boid_lookup_shader_file := load("res://src/generate_bin_boid_lookup.glsl")
var generate_boid_lookup_shader_spirv: RDShaderSPIRV = generate_boid_lookup_shader_file.get_spirv()
var generate_boid_lookup_shader := rd.shader_create_from_spirv(generate_boid_lookup_shader_spirv)
var pipeline_generate_boid_lookup := rd.compute_pipeline_create(generate_boid_lookup_shader)

var process_polygons_shader_file := load("res://src/process_polygons.glsl")
var process_polygons_shader_spirv: RDShaderSPIRV = process_polygons_shader_file.get_spirv()
var process_polygons_shader := rd.shader_create_from_spirv(process_polygons_shader_spirv)
var pipeline_process_polygons := rd.compute_pipeline_create(process_polygons_shader)

var position_buffer: RID
var position_uniform: RDUniform

var velocity_buffer: RID
var velocity_uniform: RDUniform

var param_buffer: RID
var param_uniform: RDUniform

var target_buffer: RID
var target_uniform: RDUniform

var boid_data_buffer: RID
var boid_data_uniform: RDUniform

var boid_texture: ImageTexture
var boid_texture_rd = Texture2DRD

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


var shared_boid_uniform: RID
var shared_polygon_uniform: RID


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
var boid_data: Image
var boid_data_texture: ImageTexture
var boid_data_texture_rd = Texture2DRD


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


func arrayToPackedBytes(array) -> PackedByteArray:
	var input_ := PackedFloat32Array(array)
	return input_.to_byte_array()

func createBufferFromArray(array: Array[int]):
	var input_bytes = arrayToPackedBytes(array)
	var buffer_ := rd.storage_buffer_create(input_bytes.size(), input_bytes)
	return buffer_
	
func addBox():
	var size = moving_boxes.get_child_count();
	if size >= LIST_SIZE: return ;
	moving_boxes.add_child(box.instantiate())
	
func removeLastBox():
	var size = moving_boxes.get_child_count();
	if size == 0: return
	var lastChild = moving_boxes.get_child(size - 1);
	lastChild.queue_free()
	moving_boxes.remove_child(lastChild)

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
	var updatedBuffer = arrayToPackedBytes(generate_parameter_buffer(delta))
	return rd.buffer_update(buffer_, 0, updatedBuffer.size(), updatedBuffer)


func addValueToBuffer(buffer_: RID, value: Vector2):
	var array = rd.buffer_get_data(buffer_).to_float32_array()
	var firstEmptyValueIndex = array.find(-1)

	if firstEmptyValueIndex == -1: return
	array.remove_at(firstEmptyValueIndex)
	array.remove_at(firstEmptyValueIndex)
	array.insert(firstEmptyValueIndex, value.x)
	array.insert(firstEmptyValueIndex + 1, value.y)

	var packedBytes = arrayToPackedBytes(array)
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
	var packedBytes = arrayToPackedBytes(array)
	rd.buffer_update(buffer_, 0, packedBytes.size(), packedBytes)

func replaceValueInBuffer(buffer_: RID, index: int, value: int):
	var array = rd.buffer_get_data(buffer_).to_float32_array()
	array.remove_at(index)
	array.insert(index, value)
	var packedBytes = arrayToPackedBytes(array)
	rd.buffer_update(buffer_, 0, packedBytes.size(), packedBytes)


func setupComputeShader():
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH)
	for w in IMAGE_SIZE:
		for h in IMAGE_SIZE:
			boid_data.set_pixel(w, h, Color(255, 255, 255))
			
	$BoidParticle.amount = LIST_SIZE

	var fmt := RDTextureFormat.new()
	fmt.width = IMAGE_SIZE
	fmt.height = IMAGE_SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var view := RDTextureView.new()

	var params = generate_parameter_buffer(1)

	var imagemock = []
	imagemock.resize(LIST_SIZE)
	imagemock.fill(255)

	boid_data_buffer = rd.texture_create(fmt, view, boid_data.get_data())
	boid_data_texture_rd.texture_rd_rid = boid_data_buffer
	

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


	position_uniform = createUniformFromBuffer(position_buffer, 0)
	velocity_uniform = createUniformFromBuffer(velocity_buffer, 1)
	param_uniform = createUniformFromBuffer(param_buffer, 2)
	target_uniform = createUniformFromBuffer(target_buffer, 3)
	boid_data_uniform = createUniformFromBuffer(boid_data_buffer, 4, RenderingDevice.UNIFORM_TYPE_IMAGE)
	bin_param_uniform = createUniformFromBuffer(bin_param_buffer, 5)
	bin_uniform = createUniformFromBuffer(bin_buffer, 6)
	bin_sum_uniform = createUniformFromBuffer(bin_sum_buffer, 7)
	bin_index_lookup_uniform = createUniformFromBuffer(bin_index_lookup_buffer, 8)
	bin_index_lookup_track_uniform = createUniformFromBuffer(bin_index_lookup_track_buffer, 9)
	bin_boid_index_lookup_uniform = createUniformFromBuffer(bin_boid_index_lookup_buffer, 10)

	polygon_vertex_uniform = createUniformFromBuffer(polygon_vertex_buffer, 0)
	polygon_vertex_lookup_uniform = createUniformFromBuffer(polygon_vertex_lookup_buffer, 1)

	shared_boid_uniform = rd.uniform_set_create([
		position_uniform,
		velocity_uniform,
		param_uniform,
		target_uniform,
		boid_data_uniform,
		bin_param_uniform,
		bin_uniform,
		bin_sum_uniform,
		bin_index_lookup_uniform,
		bin_index_lookup_track_uniform,
		bin_boid_index_lookup_uniform
	], run_boids_shader, 0)

	shared_polygon_uniform = rd.uniform_set_create([
		polygon_vertex_uniform,
		polygon_vertex_lookup_uniform
	], process_polygons_shader, 1)
	
	pass


func _draw():
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


func logArrayAsTable(array: Array[PackedInt32Array], name: String):
	if (name): print(name)
	for i in bin_amount_vertical:
		var row = [];
		for j in bin_amount_horizontal:
			var index = i * bin_amount_horizontal + j;
			row.push_back(array[index])
		print(row)
			

func _process(delta):
	bin_amount_horizontal = ceil(get_viewport_rect().size.x / bin_size)
	bin_amount_vertical = ceil(get_viewport_rect().size.y / bin_size)
	
	get_window().title = " / Boids: " + str(LIST_SIZE) + " / FPS: " + str(Engine.get_frames_per_second())

	updateParamBuffer(param_buffer, delta)
	
	removeLastValueFromBuffer(target_buffer)
	addValueToBuffer(target_buffer, get_global_mouse_position())
	
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		for num in 10:
			addBoid(get_viewport().get_mouse_position())
	if (Input.is_key_pressed(KEY_Q)):
		return ;

	_run_compute_shader(pipeline_generate_bin)
	_run_compute_shader(pipeline_generate_bin_sum)
	_run_compute_shader(pipeline_generate_bin_lookup)
	_run_compute_shader(pipeline_generate_boid_lookup)
	_run_compute_shader(pipeline_run_boids)


	_run_compute_shader(pipeline_process_polygons)

	#var poly = rd.buffer_get_data(polygon_vertex_lookup_buffer).to_int32_array();
	#var polyv = getVec2ArrayFromShader(polygon_vertex_buffer);
	#print(poly)
	#print(polyv)

	
func _run_compute_shader(pipeline):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, shared_boid_uniform, 0)
	rd.compute_list_bind_uniform_set(compute_list, shared_polygon_uniform, 1)
	rd.compute_list_dispatch(compute_list, round(LIST_SIZE / 1024 + 1), 1, 1)
	rd.compute_list_end()

	
func _on_add_button_pressed():
	addBox()
	addValueToBuffer(velocity_buffer, Vector2(1, 1))
	addValueToBuffer(position_buffer, Vector2(1, 1))
	pass # Replace with function body.

func addBoid(position: Vector2):
	addValueToBuffer(velocity_buffer, Vector2(1, 1))
	addValueToBuffer(position_buffer, position)


func _on_remove_button_pressed():
	removeLastBox()
	removeLastValueFromBuffer(velocity_buffer)
	removeLastValueFromBuffer(position_buffer)

	pass # Replace with function body.


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
	
	# print(polygon.polygon)
	# 0. Define polygon vertices array and polygon lookup array
	# 1. Pass polygon into shader
	# 2. Pass polygon lookup into shader
	# 3. Get the polygon center, lookup boinds at certain distance from center
	# 4. If boid is already inside polygon - do nothing, if outside - attracks to center
	# 5. For boinds inside polygon - check distance to each edge, if close - invert the velocity
	
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
	
	bin_amount_horizontal = ceil(get_viewport_rect().size.x / bin_size)
	bin_amount_vertical = ceil(get_viewport_rect().size.y / bin_size)

	
	for i in MAX_POLYGON_VERTICES:
		initial_verticies[i] = Vector2(-1, -1)
		if (i < polygon.polygon.size()):
			initial_verticies[i] = polygon.polygon[i] + polygon.position;
		initial_lookup[i] = -1;
	initial_lookup[0] = polygon.polygon.size();

	
	boid_data_texture_rd = $BoidParticle.process_material.get_shader_parameter("boid_data")
	RenderingServer.call_on_render_thread(setupComputeShader)
