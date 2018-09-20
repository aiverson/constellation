


local fmr_methodmissing

local productions = {

	take = function(source, count)
		local stype = source.tree.type
		local struct TkImpl {
			src: stype
			count: int
		}

		TkImpl.ressym = stype.ressym
		TkImpl.selfsym = symbol(TkImpl, "TkImpl_self")

		TkImpl.generate = function(skip, finish) return quote
			-- ask previous production to generate a value,
			-- store the value in stype.ressym to use in our 
			-- production 
			if [TkImpl.selfsym].count == 0 then goto [finish] end 
			[TkImpl.selfsym].count = [TkImpl.selfsym].count - 1
			[stype.generate(skip, finish)]
		end end

		TkImpl.initialize = function() return quote 
			var [stype.selfsym] = [TkImpl.selfsym].src 
			[stype.initialize()]
		end end
		
		TkImpl.metamethods.__methodmissing = fmr_methodmissing
		return `TkImpl {[source], [count]}
	end,
	
	map = function(source, transform)
		local stype = source.tree.type
		local ttype = transform.tree.type
		local struct MapImpl {
			src: stype
			mapf: ttype
		}
		--terralib.printraw(source)
		--for k, v in pairs(transform.tree.type.type) do print("stuff", k, v) end
		MapImpl.ressym = symbol(ttype.type.returntype, "MapImpl_res")
		MapImpl.selfsym = symbol(MapImpl, "MapImpl_self")
		MapImpl.generate = function(skip, finish) return quote
			[stype.generate(skip, finish)]
			[MapImpl.ressym] = [MapImpl.selfsym].mapf([stype.ressym])
		end end
		MapImpl.initialize = function() return quote
			var [stype.selfsym] = [MapImpl.selfsym].src
			var [MapImpl.ressym]
			[stype.initialize()]
		end end

		MapImpl.metamethods.__methodmissing = fmr_methodmissing
		return `MapImpl {[source], [transform]}
	end,
	filter = function(source, transform)
		local stype = source.tree.type
		local ttype = transform.tree.type
		local struct FilterImpl {
			src: stype
			filterf: ttype
		}
		--terralib.printraw(source)
		--for k, v in pairs(transform.tree.type.type) do print("stuff", k, v) end
		FilterImpl.ressym = symbol(stype.ressym.type, "FilterImpl_res")
		FilterImpl.selfsym = symbol(FilterImpl, "FilterImpl_self")
		FilterImpl.generate = function(skip, finish) return quote
			[stype.generate(skip, finish)]
			[FilterImpl.ressym] = [stype.ressym]
			if not [FilterImpl.selfsym].filterf([stype.ressym]) then
				goto [skip]
			end
		end end
		FilterImpl.initialize = function() return quote
			var [stype.selfsym] = [FilterImpl.selfsym].src
			var [FilterImpl.ressym]
			[stype.initialize()]
		end end

		FilterImpl.metamethods.__methodmissing = fmr_methodmissing
		return `FilterImpl {[source], [transform]}
	end,

	reduce = function(source, func, acc)
		--terralib.printraw(func)
		local ReduceImpl
		local stype = source.tree.type

		-- if there is an initial accumulator only generate one time
		if acc then
			local skip, finish = label("skip"), label("finish")
			return quote
				var [stype.selfsym] = [source]
				[stype.initialize(skip, finish)]
				var f = [func]
				var a = [acc]
				while true do
					:: [skip] ::
					[stype.generate(skip, finish)]
					a = f(a, [source.type.ressym])
				end
				:: [finish] ::
			in
				a
			end

		else
		-- there is no initial accumulator so we'll need to generate
		-- a skip that repeats attempts until it fails.
			local skipa, skipb, finish = label("skipa"), label("skipb"), label("finish")
			return quote
				var [stype.selfsym] = [source]
				[stype.initialize()]
				var f = [func]
				var a: func.tree.type.type.parameters[1]
				do
					:: [skipa] ::
					[stype.generate(skipa, finish)]
					a = [stype.ressym]
				end
				while true do
					:: [skipb] ::
					[stype.generate(skipb, finish)]
					a = f(a, [stype.ressym])
				end
				:: [finish] ::
			in
				a
			end
		end
	end


}

fmr_methodmissing = macro(function(method, obj, ...)
	print("method missing", method, obj, ...)
	--terralib.printraw(obj)
	return productions[method](obj, ...)
end)

local function Generator(elemt, statet)
	local struct GeneratorImpl {
		state: statet
		generate: {statet} -> {bool, elemt, statet}
	}
	GeneratorImpl.metamethods.__methodmissing = fmr_methodmissing
	GeneratorImpl.ressym = symbol(elemt)
	GeneratorImpl.selfsym = symbol(GeneratorImpl)
	GeneratorImpl.initialize = function() return quote var [GeneratorImpl.ressym] end end
	GeneratorImpl.generate = function(skip, finish) return quote
		var done: bool
		done, [GeneratorImpl.ressym], [GeneratorImpl.selfsym].state = [GeneratorImpl.selfsym].generate([GeneratorImpl.selfsym].state)
		if done then
			goto [finish]
		end
	end end
	return GeneratorImpl
end

Generator = terralib.memoize(Generator)

local struct RangeState {
	start: int
	stop: int
	step: int
}

terra rangegen(state: RangeState): tuple(bool, int, RangeState)
	var res = state.start
	state.start = res + state.step
	return {res > state.stop, res, state}
end 


local terra range(start: int, stop: int, step: int): Generator(int, RangeState)
	return [Generator(int, RangeState)] {[RangeState] {start, stop, step}, rangegen}
end


local function ArrayList(elemt)
	struct ALImpl {
		size : uint64
		capacity : uint64
		contents : &elemt
	}
	
	return ALImpl
end

local C = terralib.includec"stdio.h"

terra sqr(a: int): int --[[C.printf("%d\n", a);]] return a * a end
terra sum(a: int, b: int): int
	return a + b
end
terra even(a: int): bool return a % 2 == 0 end

terra sumofsquares(limit: int): int
	return range(1, limit, 1):map(sqr):reduce(sum)
end

terra sumofevensquares(limit: int): int
	return range(1, limit, 1):filter(even):map(sqr):reduce(sum)
end

terra first10()
	return range(1, 100, 1):take(8):take(3):reduce(sum)
end

print(first10:disas())
print(first10())

--terralib.printraw(sumofsquares)
--print(sumofsquares)
--print(sumofsquares(100))
--
--print(sumofevensquares)
--print(sumofevensquares(5))
