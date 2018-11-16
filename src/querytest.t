import "query"

iterator intrange(start: int, stop: int, step: int)
	iterate
		if start > stop then
			finish
		end
		yield start
		start = start + step
end

local res = from s in source map v = s * 2 end

local terra test(a: int): int
	return from s in intrange(1, a, 1) reduce a, b = s in a + s end
end

