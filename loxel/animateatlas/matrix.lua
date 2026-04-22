local Matrix = {}

function Matrix._2Dstruct(m)
	return m.a, m.c, 0, m.tx,
		   m.b, m.d, 0, m.ty,
		   0,   0,   1, 0,
		   0,   0,   0, 1
end

function Matrix._3Dstruct(m)
	return m.m[0], m.m[4], m.m[8],  m.m[12],
		   m.m[1], m.m[5], m.m[9],  m.m[13],
		   m.m[2], m.m[6], m.m[10], m.m[14],
		   m.m[3], m.m[7], m.m[11], m.m[15]
end

return Matrix
