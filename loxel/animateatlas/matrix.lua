local Matrix = {}

function Matrix._2D(matrix)
	return "column",
		matrix[1], matrix[2],
		0, 0,
		matrix[3], matrix[4],
		0, 0, 0, 0, 1, 0,
		matrix[5], matrix[6],
		0, 1
end

function Matrix._3D(matrix, optimized)
	if optimized then
		return "column",
			matrix[1], matrix[2],
			matrix[3], matrix[4],
			matrix[5], matrix[6],
			matrix[7], matrix[8], matrix[9], matrix[10], matrix[11], matrix[12],
			matrix[13], matrix[14],
			matrix[15], matrix[16]
	end

	return "column",
		matrix["m00"], matrix["m01"], matrix["m02"], matrix["m03"],
		matrix["m10"], matrix["m11"], matrix["m12"], matrix["m13"],
		matrix["m20"], matrix["m21"], matrix["m22"], matrix["m23"],
		matrix["m30"], matrix["m31"], matrix["m32"], matrix["m33"]
end

return Matrix
