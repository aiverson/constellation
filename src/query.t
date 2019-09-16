--[[
	query.t

	parsing for constellation query language
--]]
local parsing = require 'parsing'

local lang = {}

-- Construct AST given the Parser and a string indicating the kind of AST node
-- we'll be building a tree for
local function Tree(P, kind)
	return {kind = kind, linenumber = P:cur().linenumber, filename = P.source, offset = P:cur().offset }
end

-- Empty list of statements later used to place into the AST in situations where
-- a statement is expected, but no code should be generated.
local emptystatements = {kind = "statements", stats = terralib.newlist()}

function lang.entryStatement(P)
	if P:matches("iterator") then
		return P:iterator()
	end
	if P:matches("query") then
		return P:query()
	end
	P:error "invalid entry statement"
end

--[[
    Parsing logic for the from expression for the constellation language

    ex: from <varname> in <iterable> map mapfunc(<varname>) end 

    Returns an AST for the parsed from - in - expr 
--]]
function lang.from(P)
	-- must be a from expression
	P:expect("from")
	-- init AST for from statement 
	local tree = Tree(P, "from")
	-- Pull the name of the variable to be iterated over into varname 
	tree.varname = P:expect(P.name).value
	-- Expect the keyword in, to be followed by an expression 
	P:expect("in")
	-- parse the source expression
	tree.sourceiter = P:expression()
	-- body contains the chain of queries within this expression 
	tree.body = P:querychain()
	return tree
end


--[[
    Parsing logic for a query statement
]]

function lang.query(P)
	-- must be a query statement
	P:expect("query")
	-- build the tree for this statement
	local tree = Tree(P, "query")
	-- name of the query
	tree.name = P:expect(P.name).value
	-- parse the arglist
	tree.args = P:arglist()
	-- parse the result type
	P:expect(":")
	tree.restype = P:luaexpr()
	-- parse the body
	tree.body = P:statements()
	-- parse the closing end
	P:expect("end")
end

--[[
    Parsing logic for an iterator statement 

    currently supports the following syntax:
    	iterator <name(name: type, ...)> 
		[initialize <statement, statement, ...>]
		iterate <statement, statement, ...>
		[finalize <statement, statement, ...>]
		end
    
    Note: iterate statements must contain a yield and a finish, though that is
    not currently enforced

    TODO: Enforce the use of yield and finish
--]]
function lang.iterator(P)
	-- must be an iterator statement
	P:expect("iterator")
	-- build the tree for this statement 
	local tree = Tree(P, "iterator")
	-- tree takes a name that is the value of the iterator 
	tree.name = P:expect(P.name).value
	-- arglist is used for initialization of data structures (constructor
	-- arguments)
	tree.args = P:arglist()
	-- parse the result type
	P:expect(":")
	tree.restype = P:luaexpr()
	-- initialize is optional, and followed by statements if present
	if P:nextif("initialize") then
		tree.initialize = P:statements()
	else
		-- push noop into initialize if not present 
		tree.initialize = emptystatements
	end

	-- iterate is required
	P:expect("iterate")
	-- list of statements which control iteration of the created data type
	-- these statments must include yield and finish 
	tree.iterate = P:statements()
	
	-- finalize is optional, viewed like a destructor
	if P:nextif("finalize") then
		tree.finalize = P:statements()
	else
		-- noop if not present 
		tree.finalize = emptystatements
	end
	P:expect("end")
	return tree
end

--[[
	Construct an operation in a query chain's AST

	

--]]
function lang.queryelem(P)
	-- map operator
	-- map summap = s.a + s.b
	if P:nextif("map") then
		local tree = Tree(P, "map")
		tree.name = P:expect(P.name).value
		P:expect "="
		tree.val = P:expression()
		return tree
	elseif P:nextif("filter") then
		local tree = Tree(P, "filter")
		tree.cond = P:expression()
		return tree
	elseif P:nextif "flatten" then
		local tree = Tree(P, "flatten")
		return tree
	elseif P:nextif "reduce" then
		local tree = Tree(P, "reduce")
		tree.names = terralib.newlist{}
		tree.names:insert(P:expect(P.name).value)
		P:expect ","
		tree.names:insert(P:expect(P.name).value)
		P:expect "="
		tree.vals = terralib.newlist{}
		tree.vals:insert(P:expression())
		if P:nextif "," then
			tree.vals:insert(P:expression())
		end
		P:expect "in"
		tree.expr = P:expression()
		return tree
	end
end

-- Called to combine query elements into an AST
function lang.querychain(P)
	local tree = Tree(P, "querychain")
	tree.elems = terralib.newlist()
	repeat
		tree.elems:insert(P:queryelem())
	until P:nextif "end"
	return tree
end


function lang.statement(P)
	if P:nextif("var") then
		local tree = Tree(P, "defvar")
		tree.name = P:expect(P.name).value
		if P:nextif(":") then
			tree.type = P:luaexpr()
		end
		if P:nextif("=") then
			tree.value = P:expression()
		end
		if not (tree.type or tree.value) then
			P:error "Missing both a type and a value on a variable declaration"
		end
		return tree
	elseif P:nextif("if") then
		local tree = Tree(P, "if")
		tree.condition = P:expression()
		P:expect("then")
		tree.thenB = P:statements()
		if P:nextif("else") then
			tree.elseB = P:statements()
		else
			tree.elseB = emptystatements
		end
		P:expect("end")
		return tree
	elseif P:nextif("yield") then
		local tree = Tree(P, "yield")
		tree.val = P:expression()
		return tree
	elseif P:nextif("finish") then
		local tree = Tree(P, "finish")
		return tree
	elseif P:nextif("return") then
		local tree = Tree(P, "return")
		tree.val = P:expression()
		return tree
	else
		local tree = Tree(P, "assign")
		tree.lhs = P:expression()
		P:expect "="
		tree.rhs = P:expression()
		return tree
	end
end

lang.expression = parsing.Pratt()

lang.expression:prefix(parsing.name, function(P)
	local tree = Tree(P, "var")
	tree.name = P:next().value
	P:ref(tree.name)
	return tree
end)

lang.expression:prefix(parsing.number, function(P)
	local tree = Tree(P, "constant")
	tree.value = P:next()
	return tree
end)

lang.expression:prefix("(", function(P)
	P:next()
	local v = P:expression()
	P:expect(")")
	return v
end)

lang.expression:prefix("from", function(P)
	return P:from()
end)

lang.expression:prefix("-", function(P)
	local tree = Tree(P, "operator")
	P:next()
	tree.operator = "-"
	tree.operands = terralib.newlist {P:expression(9)}
	return tree
end)

lang.expression:infix("(", 10, function(P, lhs)
	local tree = Tree(P, "apply")
	P:next()
	tree.fn = lhs
	tree.arguments = terralib.newlist()
	if not P:lookaheadmatches ")" then
		repeat
			tree.arguments:insert(P:expression())
		until not P:nextif ","
	end
	P:expect ")"
	return tree
end)

local function doleftbinary(P, lhs)
	local tree = Tree(P, "operator")
	tree.operator = P:next().type
	tree.operands = terralib.newlist { lhs, P:expression(tree.operator) }
	return tree
end

local binaryoperators = { {"<", ">", "<=", ">=" },
			  {"-", "+"},
			  {"*", "/"} }
for prec, values in ipairs(binaryoperators) do
	for i, v in ipairs(values) do
		lang.expression:infix(v, prec, doleftbinary)
	end
end




function lang.arglist(P)
	local start_args = P:expect("(") -- collect arguments list
	local args = terralib.newlist()
	if P:matches(P.name) then --has arguments
		repeat
			local argname = P:expect(P.name).value
			P:expect(":")
			local argtype = P:luaexpr()
			args:insert({name = argname, type = argtype})
		until not P:nextif(",")
	end
	terralib.printraw(args)
	P:expectmatch(")", "(", start_args.linenumber)
	--argument list finished
	return args

end

local afterblock = {"end", "iterate", "finalize", "else"}

local canfollowblock = {}

for i, t in ipairs(afterblock) do
	canfollowblock[t] = true
end

function lang.statements(P)
	local tree = Tree(P, "statements")
	tree.stats = terralib.newlist()
	while not canfollowblock[P:cur().type] do
		tree.stats:insert(P:statement())
	end
	return tree
end

local iterskip, iterfinish, iterres = {}, {}, {} --unique identities for the symbol table

local function compile(tree, env)
	local emit
	local envstack = {env}
	local function findname(name)
		local val, index = nil, #envstack
		while not val and index > 0 do
			val = envstack[index][name]
			index = index - 1
		end
		return val
	end
	local function pushscope()
		envstack[#envstack + 1] = {}
	end
	local function popscope()
		envstack[#envstack] = nil
	end
	local function declarename(name, val)
		envstack[#envstack][name] = val
		return val
	end
	local handlers = {}
	function handlers.iterator(tree)
		local iterator = terralib.types.newstruct(tree.name)
		pushscope()
		iterator.skip = declarename(iterskip, label("iterskip"))
		iterator.finish = declarename(iterfinish, label("iterfinish"))
		iterator.ressym = declarename(iterres, symbol(tree.restype(env), "iterres"))
		for i, v in ipairs(tree.args) do
			declarename(v.name, symbol(v.type(env), v.name))
		end
		iterator.initialize = function()
			return quote [emit(tree.initialize)] end
		end
		iterator.iterate = function(ressym, skip, finish)
			pushscope()
			declarename(iterskip, skip)
			declarename(iterfinish, finish)
			declarename(iterres, ressym)
			local result = quote [emit(tree.iterate)] end
			popscope()
			return result
		end
		iterator.finalize = function()
			return quote [emit(tree.finalize)] end
		end
		popscope()
		return iterator
	end
	function handlers.yield(tree)
		return quote
			[findname(iterres)] = [emit(tree.val)]
		end
	end
	function handlers.statements(tree)
		return quote [tree.stats:map(emit)] end
	end
	handlers["if"] = function(tree)
		return quote
			if [emit(tree.condition)] then
				[emit(tree.thenB)]
			else
				[emit(tree.elseB)]
			end
		end
	end
	function handlers.operator(tree)
		terralib.printraw(tree.operands)
		local operands = tree.operands:map(emit)
		--print(operator)
		terralib.printraw(operands)
		return `operator(tree.operator, operands)
	end
	handlers["var"] = function(tree)
		return findname(tree.name)
	end
	function handlers.assign(tree)
		return quote [emit(tree.lhs)] = [emit(tree.rhs)] end
	end
	function handlers.finish(tree)
		return quote goto [findname(iterfinish)] end
	end
	function handlers.from(tree)
		pushscope()
		local stmts = terralib.newlist()
		print("trying to compile from tree")
		terralib.printraw(tree)
		local source = symbol(tree.sourceiter.restype, tree.varname)
		local sourceiter = emit(tree.sourceiter)
		local state = {
			initialize = function() 
				return sourceiter.type.initialize()
			end,
			generate = function(skip, finish)
				return sourceiter.type.generate(source, skip, finish)
			end,
			finalize = function()
				return sourceiter.type.finalize()
			end,
			ressym = source
		}
		stmts:insert(quote var [source] end)

		for i, step in ipairs(tree.body) do
			if step.kind == "map" then
				local expr = emit(step.val)
				local ressym = declarename(step.name, symbol(expr.type, step.name))
				local laststate = state
				state = {
					initialize = laststate.initialize,
					finalize = laststate.finalize,
					generate = function(skip, finish)
						return quote
							var [ressym]
							[laststate.generate(mapinput, skip, finish)]
							[ressym] = [expr]
						end
					end,
					ressym = ressym
				}
			elseif step.kind == "filter" then
				local cond = emit(step.cond)
				local laststate = state
				state = {
					initialize = laststate.initialize,
					finalize = laststate.finalize,
					generate = function(skip, finish)
						return quote
							[laststate.generate(skip, finish)]
							if [cond] then
								goto [skip]
							end
						end
					end,
					ressym = laststate.ressym
				}
			elseif step.kind == "reduce" then
				local expr1 = emit(step.vals[1])
				local expr2 = step.vals[2] and emit(step.vals[2]) or nil
				local accum = declarename(step.names[1], symbol(expr.type, step.names[1]))
				error "unable to translate reduction step"
			else
				error "unable to compile intermediate in from-expression"
			end
		end
		local skip, finish = label("skip"), label("finish")
		local result = quote
			[stmts]
			[state.initialize()]
			::[skip]::
			[state.generate(skip, finish)]
			goto [skip]
			::[finish]::
		end
		popscope()
		return result
	end
	function emit(tree)
		if handlers[tree.kind] then
			return handlers[tree.kind](tree)
		else
			terralib.printraw(tree)
			error("No compilation rule for "..tree.kind)
		end
	end
	--xpcall(emit, function(err) print(err, debug.traceback()); return err end, tree)
	return emit(tree)
end


local function exprEntry(self, lexer)
	local tree = parsing.Parse(lang, lexer, "from")
	terralib.printraw(tree)
	return function(env) return compile(tree, env()) end
end

local function statementEntry(self, lexer)
	local tree = parsing.Parse(lang, lexer, "entryStatement")
	terralib.printraw(tree)
	return function(env) return compile(tree, env()) end
end

return {
	name = "query",
	entrypoints = {"query", "from", "iterator"},
	keywords = {"initialize", "iterate", "finish", "skip", "yield", "map", "filter", "reduce", "flatten"},
	expression = exprEntry,
	statement = statementEntry,
}
