class_name BoidRunner
var rd := RenderingServer.get_rendering_device()

var BufferUtils: BufferUtils = preload("res://src/utils/buffer/BufferUtils.gd").new()

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


var width = null;
var height = null;
var boid_amount = 0;
var bin_size = 0;


func createBoidUniform(params):
	var IMAGE_SIZE = int(ceil((sqrt(boid_amount))));
	prints("IMAGE SIUZE", IMAGE_SIZE)
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH)
	var format_boid_data := RDTextureFormat.new()
	format_boid_data.width = IMAGE_SIZE
	format_boid_data.height = IMAGE_SIZE
	format_boid_data.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format_boid_data.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	

	boid_data_texture_buffer = rd.texture_create(format_boid_data, RDTextureView.new(), boid_data.get_data())

	position_buffer = BufferUtils.vec2ToBuffer(inital_position)
	velocity_buffer = BufferUtils.vec2ToBuffer(initial_velocity)
	target_buffer = BufferUtils.vec2ToBuffer(([Vector2(-1, -1)]))
	param_buffer = BufferUtils.floatToBuffer(params)

	bin_param_buffer = BufferUtils.intToBuffer([bin_size, getBinAmount()])
	bin_buffer = BufferUtils.intToBuffer(bin)
	bin_sum_buffer = BufferUtils.intToBuffer(binSum)
	bin_index_lookup_buffer = BufferUtils.intToBuffer(binLookup)
	bin_index_lookup_track_buffer = BufferUtils.intToBuffer(binLookupTrack)
	bin_boid_index_lookup_buffer = BufferUtils.intToBuffer(binIndexBoidLookup)


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

	return rd.uniform_set_create([
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


func createPolygonUniform():
	polygon_vertex_buffer = BufferUtils.vec2ToBuffer(initial_verticies)
	polygon_vertex_lookup_buffer = BufferUtils.intToBuffer(initial_lookup)


	polygon_vertex_uniform = BufferUtils.createUniformFromBuffer(polygon_vertex_buffer, 0)
	polygon_vertex_lookup_uniform = BufferUtils.createUniformFromBuffer(polygon_vertex_lookup_buffer, 1)
	

	return rd.uniform_set_create([
		polygon_vertex_uniform,
		polygon_vertex_lookup_uniform
	], process_polygons_shader, 1)


func createHeatmapUniform():
	heatmap = Image.create(width, height, false, Image.FORMAT_RGBAH)

	var format_heatmap := RDTextureFormat.new()
	format_heatmap.width = width
	format_heatmap.height = height
	format_heatmap.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format_heatmap.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	heatmap_texture_buffer = rd.texture_create(format_heatmap, RDTextureView.new(), heatmap.get_data())


	boid_heatmap_buffer = BufferUtils.intToBuffer(initial_heatmap)

	boid_heatmap_uniform = BufferUtils.createUniformFromBuffer(boid_heatmap_buffer, 0)
	heatmap_texture_uniform = BufferUtils.createUniformFromBuffer(heatmap_texture_buffer, 1, RenderingDevice.UNIFORM_TYPE_IMAGE)


	return rd.uniform_set_create([
		boid_heatmap_uniform,
		heatmap_texture_uniform
	], create_heatmap_shader, 2)
	
	
func initalize(LIST_SIZE: int, MAX_POLYGON_VERTICES: int, PREFILL: bool, viewport: Rect2, bin_size_: int):
	width = viewport.size.x;
	height = viewport.size.y;
	boid_amount = LIST_SIZE;
	bin_size = bin_size_;
	var bin_amount = getBinAmount()
	inital_position.resize(LIST_SIZE)
	initial_velocity.resize(LIST_SIZE)
	if (PREFILL):
		for i in LIST_SIZE:
			inital_position[i] = Vector2(
				randf() * viewport.size.x,
				randf() * viewport.size.y
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
	binSum.resize(bin_amount)
	binSum.fill(0)
	binLookup.resize(bin_amount)
	binLookup.fill(0)
	binLookupTrack.resize(bin_amount)
	binLookupTrack.fill(0)
	binIndexBoidLookup.resize(LIST_SIZE)
	binIndexBoidLookup.fill(0)
	
	initial_lookup.resize(MAX_POLYGON_VERTICES)
	initial_verticies.resize(MAX_POLYGON_VERTICES)
	initial_heatmap.resize(viewport.size.x * viewport.size.y)
	initial_heatmap.fill(0)
	
	var bin_amount_horizontal = ceil(viewport.size.x / bin_size)
	var bin_amount_vertical = ceil(viewport.size.y / bin_size)
	return [bin_amount_horizontal, bin_amount_vertical]
	
	
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
	var x = width
	var y = height
	return ceil(x / bin_size) * ceil(y / bin_size) * 6
