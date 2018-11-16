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
	-- Select the expression as a luaexpr
	-- TODO: Should probably be a constellation expression rather than lua 
	tree.sourceiter = P:luaexpr()
	-- body contains the chain of queries within this expression 
	tree.body = P:querychain()
	return tree
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
	end
	local handlers = {}
	local iter_res = {} --unique identity for the iterator result
	function handlers.iterator(tree)
		local iterator = terralib.types.newstruct(tree.name)
		pushscope()
		for i, v in ipairs(tree.args) do
			declarename(v.name, symbol(v.type(env), v.name))
		end
		iterator.initialize = quote [emit(tree.initialize)] end
		iterator.iterate = quote [emit(tree.iterate)] end
		iterator.finalize = quote [emit(tree.finalize)] end
		popscope()
		return iterator
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
		print(operator)
		terralib.printraw(operands)
		return `operator(tree.operator, operands)
	end
	handlers["var"] = function(tree)
		return findname(tree.name)
	end
	function handlers.finish(tree)
		return quote goto finish end
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
	local tree = parsing.Parse(lang, lexer, "iterator")
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
