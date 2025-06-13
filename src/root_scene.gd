extends Node2D


const LIST_SIZE = 50000;
const MAX_POLYGON_VERTICES = 200;

var rd := RenderingServer.get_rendering_device()
const MOUSE_ACTION = "MouseButtonLeft"


var BoidRunner: BoidRunner = preload("res://src/BoidRunner.gd").new()
var BufferUtils: BufferUtils = preload("res://src/utils/buffer/BufferUtils.gd").new()


var LOG_BINS = false;

@onready var particle: GPUParticles2D = $BoidParticle

@onready var polygon = $Polygon2D
@onready var polygons = $Polygons


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
	var updatedBuffer = BufferUtils.floatArrayToPackedBytes(generate_parameter_buffer(delta))
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
	var verticies = BufferUtils.vec2ArrayToPackedBytes(g[0]);
	var lookup = BufferUtils.intArrayToPackedBytes(g[1])
	
	rd.buffer_update(polygon_vertex_buffer, 0, verticies.size(), verticies)
	rd.buffer_update(polygon_vertex_lookup_buffer, 0, lookup.size(), lookup)
	
	
func updateHeatmapBuffer():
	heatmap.resize(get_viewport_rect().size.x, get_viewport_rect().size.y)
	var format_heatmap := RDTextureFormat.new()
	format_heatmap.width = get_viewport_rect().size.x
	format_heatmap.height = get_viewport_rect().size.y
	format_heatmap.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format_heatmap.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	heatmap_texture_buffer = rd.texture_create(format_heatmap, RDTextureView.new(), heatmap.get_data())

func setupComputeShader():
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH)
	heatmap = Image.create(DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y, false, Image.FORMAT_RGBAH)
			
	$BoidParticle.amount = LIST_SIZE

	var format_boid_data := RDTextureFormat.new()
	format_boid_data.width = IMAGE_SIZE
	format_boid_data.height = IMAGE_SIZE
	format_boid_data.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format_boid_data.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	

	var format_heatmap := RDTextureFormat.new()
	format_heatmap.width = DisplayServer.screen_get_size().x
	format_heatmap.height = DisplayServer.screen_get_size().y
	format_heatmap.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format_heatmap.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	var params = generate_parameter_buffer(1)

	boid_data_texture_buffer = rd.texture_create(format_boid_data, RDTextureView.new(), boid_data.get_data())
	boid_data_texture_rd.texture_rd_rid = boid_data_texture_buffer

	heatmap_texture_buffer = rd.texture_create(format_heatmap, RDTextureView.new(), heatmap.get_data())
	heatmap_texture_rd.texture_rd_rid = heatmap_texture_buffer
	
	position_buffer = BufferUtils.vec2ToBuffer(inital_position)
	velocity_buffer = BufferUtils.vec2ToBuffer(initial_velocity)
	param_buffer = BufferUtils.floatToBuffer(params)
	target_buffer = BufferUtils.vec2ToBuffer(([Vector2(-1, -1)]))
	bin_param_buffer = BufferUtils.intToBuffer([bin_size, getBinAmount()])
	bin_buffer = BufferUtils.intToBuffer(bin)
	bin_sum_buffer = BufferUtils.intToBuffer(binSum)
	bin_index_lookup_buffer = BufferUtils.intToBuffer(binLookup)
	bin_index_lookup_track_buffer = BufferUtils.intToBuffer(binLookupTrack)
	bin_boid_index_lookup_buffer = BufferUtils.intToBuffer(binIndexBoidLookup)

	polygon_vertex_buffer = BufferUtils.vec2ToBuffer(initial_verticies)
	polygon_vertex_lookup_buffer = BufferUtils.intToBuffer(initial_lookup)

	boid_heatmap_buffer = BufferUtils.intToBuffer(initial_heatmap)


	position_uniform = BufferUtils.createUniformFromBuffer(position_buffer, 0)
	velocity_uniform = BufferUtils.createUniformFromBuffer(velocity_buffer, 1)
	param_uniform = BufferUtils.createUniformFromBuffer(param_buffer, 2)
	target_uniform = BufferUtils.createUniformFromBuffer(target_buffer, 3)
	boid_data_texture_uniform = BufferUtils.createUniformFromBuffer(boid_data_texture_buffer, 4, RenderingDevice.UNIFORM_TYPE_IMAGE)
	bin_param_uniform = BufferUtils.createUniformFromBuffer(bin_param_buffer, 5)
	bin_uniform = BufferUtils.createUniformFromBuffer(bin_buffer, 6)
	bin_sum_uniform = BufferUtils.createUniformFromBuffer(bin_sum_buffer, 7)
	bin_index_lookup_uniform = BufferUtils.createUniformFromBuffer(bin_index_lookup_buffer, 8)
	bin_index_lookup_track_uniform = BufferUtils.createUniformFromBuffer(bin_index_lookup_track_buffer, 9)
	bin_boid_index_lookup_uniform = BufferUtils.createUniformFromBuffer(bin_boid_index_lookup_buffer, 10)

	polygon_vertex_uniform = BufferUtils.createUniformFromBuffer(polygon_vertex_buffer, 0)
	polygon_vertex_lookup_uniform = BufferUtils.createUniformFromBuffer(polygon_vertex_lookup_buffer, 1)
	
	boid_heatmap_uniform = BufferUtils.createUniformFromBuffer(boid_heatmap_buffer, 0)
	heatmap_texture_uniform = BufferUtils.createUniformFromBuffer(heatmap_texture_buffer, 1, RenderingDevice.UNIFORM_TYPE_IMAGE)

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
	], BoidRunner.run_boids_shader, 0)

	shared_polygon_uniform = rd.uniform_set_create([
		polygon_vertex_uniform,
		polygon_vertex_lookup_uniform
	], BoidRunner.process_polygons_shader, 1)

	shared_heatmap_uniform = rd.uniform_set_create([
		boid_heatmap_uniform,
		heatmap_texture_uniform
	], BoidRunner.create_heatmap_shader, 2)
	

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
	BufferUtils.addValueToBuffer(target_buffer, get_global_mouse_position())
	_run_compute_shader(BoidRunner.pipeline_generate_bin_sum)
	if (Input.is_key_pressed(KEY_Q)):
		return ;
	updateParamBuffer(param_buffer, delta)
	updatePolygonBuffers()
	
	BufferUtils.removeLastValueFromBuffer(target_buffer)

	
	_run_compute_shader(BoidRunner.pipeline_generate_bin)
	_run_compute_shader(BoidRunner.pipeline_generate_bin_lookup)
	_run_compute_shader(BoidRunner.pipeline_generate_boid_lookup)
	_run_compute_shader(BoidRunner.pipeline_run_boids)
	_run_compute_shader_screen(BoidRunner.pipeline_create_heatmap)

	_run_compute_shader(BoidRunner.pipeline_process_polygons)

func _process(delta):
	queue_redraw()
	bin_amount_horizontal = ceil(get_viewport_rect().size.x / bin_size)
	bin_amount_vertical = ceil(get_viewport_rect().size.y / bin_size)
	
	get_window().title = " / Boids: " + str(LIST_SIZE) + " / FPS: " + str(Engine.get_frames_per_second())
	
	if (Input.is_key_pressed(KEY_W)):
		for p in polygons.get_children():
			p.queue_free()
	if (Input.is_action_pressed((MOUSE_ACTION))):
		addBoid(get_viewport().get_mouse_position(), 10)
	if (Input.is_key_pressed(KEY_Q)):
		return ;
		
		
	if (RENDER_BIN):
		var b = rd.buffer_get_data(bin_buffer).to_int32_array()
		var bss = rd.buffer_get_data(bin_sum_buffer).to_int32_array()
		var ss = rd.buffer_get_data(bin_index_lookup_buffer).to_int32_array()
		var bs = rd.buffer_get_data(bin_boid_index_lookup_buffer).to_int32_array()
		print("Bin amount", getBinAmount())
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
		BufferUtils.addValueToBuffer(velocity_buffer, Vector2(1, 1))
		BufferUtils.addValueToBuffer(position_buffer, position_)
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
	BufferUtils.addValueToBuffer(velocity_buffer, velocities)
	BufferUtils.addValueToBuffer(position_buffer, positions)
	

func getBinAmount():
	var x = get_viewport_rect().size.x
	var y = get_viewport_rect().size.y
	return ceil(x / bin_size) * ceil(y / bin_size) * 6

func _ready():
	get_tree().get_root().size_changed.connect(onResize)
	$CanvasLayer/ColorRect.set_size(DisplayServer.screen_get_size())



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


func onResize():
	pass;
