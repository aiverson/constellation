
local malloc = terralib.externfunction("malloc", {uint64} -> {&opaque})
local free = terralib.externfunction("free", {&opaque} -> {})
local C = terralib.includec("stdio.h")

local methods = {
	map = function(obj, func)
		struct MapImpl {
			source: obj:gettype();
			fp: func:gettype();
		}
		local ressym = terralib.symbol("looptemp", 
		MapImpl.metamethods.loopfragment = 


local function ArrayList(elemt)
	local struct ALImpl {
		cap : uint64;
		size : uint64;
		s : &elemt;
	}
	
	ALImpl.elemt = elemt

	-- init: Create a new ArrayList with capacity
	--
	-- Args:
	--	cap: Desired capacity of ArrayList
	terra ALImpl:init(cap: uint64) 
		self.cap = cap 
		self.size = 0
		self.s = [&elemt] (malloc(self.cap * terralib.sizeof(elemt)))
	end

	-- destroy: free resources for list
	terra ALImpl:destroy()
		free(self.s)
	end

	-- append: 
	terra ALImpl:append(elem: elemt)
		if (self.size + 2) > self.cap then
			self.cap = self.cap * 2
			var nb = [&elemt] (malloc(self.cap * terralib.sizeof(elemt)))
			for i=0, self.size do
				nb[i] = self.s[i]
			end

			free(self.s)
			self.s = nb
		end

		self.s[self.size] = elem 
		self.size = self.size + 1
	end

	-- get: 
	terra ALImpl:get(offset: uint64)
		return self.s[offset]
	end

	-- set:
	terra ALImpl:set(offset: uint64, elem: elemt)
		self.s[offset] = elem
	end

	return ALImpl
end

ArrayList = terralib.memoize(ArrayList)
local ints = ArrayList(int)
terra tstfn()

	var lst : ints
	lst:init(10)

	var i : int
	for i=0, 21 do
		C.printf("Appending %d\n", i)
		lst:append(i)
	end

	for i=0, 21 do
		lst:set(i, 21 - i)
	end

	for i=0, 21 do
		C.printf("I: %d -> %d\n", i, lst:get(i))
	end

	lst:destroy()
end

terralib.saveobj("arrlsttst", { main = tstfn }, {"-g"})
