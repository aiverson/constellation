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
itself specifically well to multistage programming. Despite being a relatively 
new language Terra has quickly found itself on the cutting edge of applications
varying from high speed physics simulations to digital image processing.

Terra also includes a toolkit for implementing domain specific languages which 
may be embedded in Terra programs.

# Constellation: Simpler and Faster

Here we will take a brief moment to conduct a general overview of the syntax of 
Constellation.

## An Example for Motivation

```Lua

function 

end
```

```

cqf symbols(d : iterable)
	from d select unique .ticker
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