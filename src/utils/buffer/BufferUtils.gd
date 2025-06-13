class_name BufferUtils

var rd := RenderingServer.get_rendering_device()

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
