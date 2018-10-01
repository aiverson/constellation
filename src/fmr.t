--[[
file: constellation/src/fmr.t
authors: Alex Iverson, Lawrence Hoffman

fmr.t implements a first proof of concept for compiling out filter-map-reduce 
type queries into an optimized and native format. The methods exposed by fmr 
are meant as an interface for the back end of constellation.

When considering the functions in the productions table it is important to keep
in mind that this is code being generated, which actually operates on code 
being fed to it, and returns values in line with an interface which while 
expected of any code added to the productions table is not enforced anywhere.

Each of the production functions needs to follow a certain format.
	(1) A function called initialize which inits the current function
	(2) A function called generate wich conducts the business of this 
	    stage in the pipeline
	(3) Override the .metamethods.__methodmissing with the fmr_methodmissing 
	    macro. 

We're hoping to get the functions in this file heavily enough documented that 
any programmer who wishes might be able to add whatever they need on the fly.
--]]

local C = terralib.includec"stdio.h"

local fmr_methodmissing

local productions = {

	--[[
	function: diff
	
	diff returns a list with the 'difference' function passed applied to 
	each consecutive pair of items in the iterable.

	So... if our iterable looks like [ 1, 4, 5 ] and we passed a simple 
	subtraction function, then we aught to get [ 3, 1 ] as a result here.
	--]]
	diff = function(source, func)
		local stype = source.tree.type 
		local ttype = func.tree.type

		local struct DiffImpl {
			src: stype
			difff: ttype
		}

		DiffImpl.ressym = symbol(ttype.type.returntype, "DiffImpl_ressym") 
		DiffImpl.selfsym = symbol(DiffImpl, "DiffImpl_self")
		local first = symbol(bool, "DiffImpl_first_pass")
		local lval = symbol(ttype.type.parameters[1], "DiffImpl_lval")
		DiffImpl.generate = function(skip, finish) return quote
			if [first] then
				[stype.generate(skip, finish)]
				[lval] = [stype.ressym]
				[first] = false
				goto [skip] 
			else
				[stype.generate(skip, finish)]
				[DiffImpl.ressym] = [DiffImpl.selfsym].difff([lval], [stype.ressym])
				[lval] = [stype.ressym]
			end
		end end

		DiffImpl.initialize = function() return quote
			var [stype.selfsym] = [DiffImpl.selfsym].src
			var [DiffImpl.ressym]
			var [first] = true
			var [lval]
			[stype.initialize()]
		end end

		DiffImpl.metamethods.__methodmissing = fmr_methodmissing
		return `DiffImpl {[source], [func]}
	end,

	--[[
	function: take

	take returns the first 'count' values from the iterable. 
	--]]
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

	--[[
	function: map

	map takes a transformation function which mutates an iterable and 
	applies that function elementwise on the iterable.
	--]]
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

	--[[
	function: filter

	filter selects or removes elements from an iterable by application of 
	the given transofrm function.
	--]]
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

	--[[
	function: each

	simplistic function to step over each value in the iterable

	--]]
	each = function(source, appfn)
		
		-- hold the source type 
		local stype = source.tree.type
		
		-- create labels for skip and finish so that we can jump to 'em
		local skip, finish = label("skip"), label("finish")

		-- the function to be applied is an optional argument, it may 
		-- not be there, if it is, we want to apply the function to 
		-- every element 
		if appfn then
			return quote
				-- set the symbol for our source arg 
				var [stype.selfsym] = [source]

				-- initialize the function before us 
				[stype.initialize()]

				-- this is the local name for the application 
				-- function 
				var f = [appfn]

				-- loop all of the generated elements of the 
				-- preceding function
				while true do
					
					-- skip label at the top of the loop
					:: [skip] ::
					
					-- ask function before us in the chain
					-- for a vaule
					[stype.generate(skip, finish)]

					-- run our appfn on the generated value 
					-- note that we're not storing the  
					-- result of the appfn anywhere. 
					f([stype.ressym])
				end
				
				-- our finish label
				:: [finish] ::
			end
		else	
			-- no appfn given, so we're just going to run an empty 
			-- pass on each item generated 
			return quote 
				
				-- we must set our own symbol 
				var [stype.selfsym] = [source]

				-- initialize the code that's set to run ahead 
				-- of us
				[stype.initialize()]
				while true do
					
					-- our skip label
					:: [skip] ::

					-- tell the code that's ahead of us to 
					-- generate the next value 
					[stype.generate(skip, finish)]
				end

				-- our finish label
				:: [finish] ::
			end
		end

	end,

	--[[
	function: reduce

	reduces an iterable via func, possibly with accumulation
	--]]
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

terra printInt(a: int): int 
	C.printf("%d, ", a)
end

terra diffAdd()
	return range(1, 6, 1):each(printInt)
end

diffAdd:disas()
print(diffAdd)
diffAdd()
--print(first10:disas())
--print(first10())

--terralib.printraw(sumofsquares)
--print(sumofsquares)
--print(sumofsquares(100))
--
--print(sumofevensquares)
--print(sumofevensquares(5))
