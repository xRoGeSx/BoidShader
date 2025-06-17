extends Node2D

var rd := RenderingServer.get_rendering_device()

var BoidRunner: BoidRunner = preload("res://src/BoidRunner.gd").new()
var BufferUtils: BufferUtils = preload("res://src/utils/buffer/BufferUtils.gd").new()
var LogUtils: LogUtils = preload("res://src/utils/log/LogUtils.gd").new()

@export_category("Simulation settings")
@export var LIST_SIZE = 50000;
@export var MAX_POLYGON_VERTICES = 200;
@export var PREFILL = true;
@export var RENDER_BIN = true;
@export var bin_size = 16;

@export_category("Boid Settings")
@export_range(0, 50) var friend_radius = 10.0
@export_range(0, 50) var avoid_radius = 5.0
@export_range(0, 100) var min_vel = 50.0
@export_range(0, 500) var max_vel = 75.0
@export_range(0, 100) var alignment_factor = 10.0
@export_range(0, 100) var cohesion_factor = 1.0
@export_range(0, 100) var separation_factor = 20.0

const MOUSE_ACTION = "MouseButtonLeft"



@onready var particle: GPUParticles2D = $BoidParticle
@onready var polygon = $Polygon2D
@onready var polygons = $Polygons

var boid_data_texture_rd = Texture2DRD
var heatmap_texture_rd = Texture2DRD

var shared_boid_uniform: RID
var shared_polygon_uniform: RID
var shared_heatmap_uniform: RID


var width = 400
var height = 200




var bin_amount_horizontal = ceil(get_viewport_rect().size.x / bin_size)
var bin_amount_vertical = ceil(get_viewport_rect().size.y / bin_size)
var bin_amount = bin_amount_horizontal * bin_amount_vertical
var IMAGE_SIZE = int(ceil((sqrt(LIST_SIZE))));

func generateParameters(delta):
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
	var updatedBuffer = BufferUtils.floatArrayToPackedBytes(generateParameters(delta))
	return rd.buffer_update(buffer_, 0, updatedBuffer.size(), updatedBuffer)

func updatePolygonBuffers():
	var g = generate_polygon_buffers()
	var verticies = BufferUtils.vec2ArrayToPackedBytes(g[0]);
	var lookup = BufferUtils.intArrayToPackedBytes(g[1])
	
	rd.buffer_update(BoidRunner.polygon_vertex_buffer, 0, verticies.size(), verticies)
	rd.buffer_update(BoidRunner.polygon_vertex_lookup_buffer, 0, lookup.size(), lookup)
	
	
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




func _physics_process(delta):
	BufferUtils.addValueToBuffer(BoidRunner.target_buffer, get_global_mouse_position())
	_run_compute_shader(BoidRunner.pipeline_generate_bin_sum)
	if (Input.is_key_pressed(KEY_Q)):
		return ;
	updateParamBuffer(BoidRunner.param_buffer, delta)
	updatePolygonBuffers()
	
	BufferUtils.removeLastValueFromBuffer(BoidRunner.target_buffer)

	
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
		BoidRunner.addBoid(get_viewport().get_mouse_position(), 20)
	if (Input.is_key_pressed(KEY_Q)):
		return ;
		
		
	if (RENDER_BIN):
		var b = rd.buffer_get_data(BoidRunner.bin_buffer).to_int32_array()
		var bss = rd.buffer_get_data(BoidRunner.bin_sum_buffer).to_int32_array()
		var ss = rd.buffer_get_data(BoidRunner.bin_index_lookup_buffer).to_int32_array()
		var bs = rd.buffer_get_data(BoidRunner.bin_boid_index_lookup_buffer).to_int32_array()
		print("Bin amount", BoidRunner.getBinAmount())
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




func _ready():
	get_tree().get_root().size_changed.connect(onResize)
	$CanvasLayer/ColorRect.set_size(DisplayServer.screen_get_size())
	
	BoidRunner.initalize(LIST_SIZE, MAX_POLYGON_VERTICES, PREFILL, get_viewport_rect(), bin_size)
	
	boid_data_texture_rd = $BoidParticle.process_material.get_shader_parameter("boid_data")
	heatmap_texture_rd = $CanvasLayer/ColorRect.material.get_shader_parameter("heatmap")
	RenderingServer.call_on_render_thread(setupComputeShader)
	

func setupComputeShader():
	$BoidParticle.amount = LIST_SIZE
	var params = generateParameters(1)

	# Create uniforms 
	shared_boid_uniform = BoidRunner.createBoidUniform(params)
	shared_polygon_uniform = BoidRunner.createPolygonUniform()
	shared_heatmap_uniform = BoidRunner.createHeatmapUniform()
	
	# Pass shared data to render shaders
	boid_data_texture_rd.texture_rd_rid = BoidRunner.boid_data_texture_buffer
	heatmap_texture_rd.texture_rd_rid = BoidRunner.heatmap_texture_buffer
	

func _on_shape_spawner__on_item_selected(polygon_: Polygon2D):
	polygon_.position = get_global_mouse_position()
	polygons.add_child(polygon_.duplicate())
	updatePolygonBuffers()
	pass # Replace with function body.


func onResize():
	pass ;
