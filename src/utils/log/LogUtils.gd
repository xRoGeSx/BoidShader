class_name LogUtils

func logArrayAsTable(array: Array[PackedInt32Array], r: int, c: int, name_: String):
	if (name_): print(name_)
	for i in r:
		var row = [];
		for j in c:
			var index = i * c + j;
			row.push_back(array[index])
		printt(row)
			
