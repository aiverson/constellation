# Introduction

## Constellation - An integrated data query and description language for Terra

Constellation seeks to bring structured and optimized data queries to standard
Lua and Terra types in the Terra programming language. These queries are the 
result of a custom domain specific language which translates to native search
queries on general user defined data structures.

## Design goals of Constellation 

Constellation is designed with simplicity and efficiency in mind. It is the 
hope of the authors that the language is small enough to be easily learnt in a
short session with the documentation, yet powerful enough to quickly become a
staple tool for any serious Terra programmer.

### Simplicity

Constellation consists of a small number of keywords and operators which may 
be composed to create highly readable high level queries on data structures 
native to the Terra programming language.

### Performance

The result of writing a complex query in Constellation will perform *at least* 
as fast as the query written in native Terra. This performance is a achieved 
by the Constellation compiler which is designed from the ground up with the 
specific intent of addressing performance issues in data queries.

### Familiarity

The language of Constellation is very similar to a simplified SQL language. 
This similarity is intentional, any programmer with experience writing SQL 
queries should immediately understand the syntax of Constellation.

## Why Terra 

Terra was chosen as a host language due to the flexibility offered by the 
design of Terra, which integrates Lua, a high level scripting language with a
small low level programming language, Terra. The result is a rich language that
is capable of on the fly run time code generation, self optimization, and lends
itself especially well to multistage programming. Despite being a relatively 
new language Terra has quickly found itself on the cutting edge of applications
varying from high speed physics simulations to digital image processing.

Terra also includes a toolkit for implementing domain specific languages which 
may be embedded in Terra programs.

# Constellation: Simpler and Faster

Here we will take a brief moment to conduct a general overview of the syntax of 
Constellation.

## An Example for Motivation

Suppose that we have a bunch of stock data in a map which is keyed on dates 
pointing to data structures containing information about various stocks. We 
to get a list of unique ticker symbols in our data set.

```Lua

function get_tickers(stock_data)
	local ticker, retval = {}, {} 
	for i=1, #stock_data do
		if ticker[stock_data[i].ticker] == nil then
			retval[#retval + 1] = stock_data[i].ticker
			ticker[stock_data[i].ticker] = true
		end
	end
	return retval
end

function get_tickers(stock_data)
	local set, list = {}, {}
	for _, v in ipairs(stock_data) do set[v.ticker] = true end
	for name, _ in pairs(set) do table.insert(list, name) end
	return list
end
```

With Constellation we might express the same functionality as:

```
	local ticker_symbols = from d in stock_data unique d.ticker map d.ticker end 
```

Obviously the latter case is faster to type. Additionally, due to some 
optimization steps which can be applied generally to these sorts of queries 
Constellation can also produce code which is likely to run faster than the 
code a human is likely to write.

As a further, more complicated example consider the following:

```
	local dailydeltas = from d in stock_data
		ticker, delta = groupBy d.ticker do
			volume = groupBy d.date do
				reduce volume = 0 in volume + d.volume
			end
			delta = diff a, b = volume in a - b
			list = build List {date = d.date, delta = delta}
			return d.ticker, list
		end
		build Map (ticker, delta)
	end
```


# Unformatted Rambling

Constellation consists of two main interacting components: The datastructure
definition language and the query language.

The Datastructure definition language will allow creating, combining, and
customizing datastructures and algorithms in a flexible and composable way.
These datastructures will expose a normal terra interface suitable for use in any
terra code as well as compiling a library for C, C++, or anything else with a
compatible ABI.

The query language will have an iterator based interface and a syntax inspired by LINQ.
It will provide a simple way to build optimized produce-transduce-consume chains,
either for inline use, or exporting as a library.

The datastructure definition language will have a variety of facilities to produce
iterators compatible with the query language easily, and queries may be embeded in
algorithmic definitions.

The limitations of conventional templating systems and libraries, like the C++ STL
provides a sharp limit on their abilities to provide algorithmic facilities, 
resulting in the necessity of reimplementing large sections of common algorithms
for each new use rather than just specifying the small sections that are different.
Constellation DSA will allow producing configurable and templatized mixins which
efficiently implement the desired behavior with a minimum of boiler plate.

One advantage of the Constellation DSA approach is the ability to define
intrusive datastructures easily. In languages with powerful MetaObject Protocols
(MOPs), intrusive datastructures can be defined, though they are typically not
very clean implementations. MOPs require a significant amount of indirection,
computation, and runtime overhead, so these datastructures cannot match
handwritten native implementations. Existing languages using conventional
templates without a MOP are able to create very efficient extrusive datastructures,
but are completely incapable of creating intrusive datastructures. Constellation
will be capable of efficiently and cleanly defining both intrusive and extrusive
datastructures, and will allow sharing most of the implementation code between
them and will allow interchangeable usage of the common features.

A capabilities and aspect based system with syntax support will allow
datastructures and algorithms to specify their interactions in a manner which
makes them composable automatically, so even very dissimilar datastructures and
algorithms can be seamlessly woven together in a common collection without
extensive manual work joining them together.

Constellation Query will allow producing highly efficient in-memory queries by
use of extensive inlining and minimal indirection. Constellation queries will
produce native code implementing the entire query chain in a single code block,
which avoids both the high memory usage and cache misses of intermediate arrays
and the many indirections required for chained iterators.

Constellation DSA will be based on Aspect Oriented Programming, though with a more
restricted form of pointcut to permit full compilation and inlining of advice and
to reduce the nonlocality caused by normal AOP. An algorithm implementation may expose
pointcuts whereby additional operations may be composed. This allows customizing
standard algorithms for a particular need with no extra overhead. Every datastructure will
expose a pointcuts with various granularites on modifications to permit composed structures
to update dependent structures. These must never produce a loop. A collection may be
composed of multiple data structures. These datastructures may provide implementations
of many methods. The system of advice and pointcuts will permit specializing the
datastructures and automate the process of crosslinking data between them where
necessary.

There will be a special syntax support for creating iterators from scratch as
well as for querying them. Syntax example for creating an iterator type over
ranges of integers follows.

```
iterator intrange(start: int, stop: int, step: int)
		var val: int
	initialize
		val = start
	iterate
		if val > stop then
			finish
		end
		yield val
		val += step
	finalize
		--no finalization behavior necessary here
end

query sumofsquares(limit: int)
	from i in intrange(1, limit, 1)
		map s = i * i
		reduce sum = 0 by sum + s
	end
end
```

This will allow creating iterators easily over any object in Terra which will
greatly ease integrating new datasources and libraries into Constellation.