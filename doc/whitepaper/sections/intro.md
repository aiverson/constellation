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
queries should quickly become comfortable with the syntax of Constellation.

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

# Language Design Overview

Constellation consists of two main interacting components: The data structure
definition language and the query language.

## The Data Structure Definition Language

The data structure definition language aims to provide a syntax used to create,
customize, and combine data structures. This syntax is designed with 
flexibility and composition in mind, allowing abstractions that are more 
powerful than those provided by typical object oriented languages. The produced
data structures implement normal terra interfaces, allowing them to be used in 
any other terra code, or compiled to an object file for linking with C, C++ or 
any other language featuring a compatible ABI.

### Iterators

At the core of the data structure definition language is the generalization of 
iterator types that can be generated from more basic data structures (like 
arrays, lists, trees, and graphs.) These iterators are composed with the query 
language in mind, such that the queries may be embedded in the definitions.

### Not a Template System

Template systems, like that of the C++ STL, are limited in their support of 
meta-programmed algorithms. The result is that algorithms are often rewritten 
in their entirety for a new data structure, rather than modifying the one or two
statements necessary to adapt a generalized algorithm to the new type. The 
Constellation data structure language seeks to provide the features of a 
template system, along with mixins, in a configurable and efficient package 
which enables the creation of new types with minimal boiler plate requirements.

### Data Structure Efficiency 

The Constellation data structure definition language seeks to meet or exceed 
the efficiency of hand written native code, as such intrusive data structures
have been given special thought. Languages which feature powerful MetaObject 
Protocols (MOP) enable programmers to create intrusive data structures. 
However, the resulting data structures and associated algorithms tend to be far 
slower than native implementations, as they are hampered by significant amounts 
of indirection, computation, and runtime overhead. Languages featuring 
conventional template systems are capable of defining highly efficient 
extrusive data structures but completely lack the ability to create intrusive 
data structures. Constellation looks to make the creation of both intrusive and
extrusive data structures cleanly and efficiently. Additionally, most of the 
implementation code between the two is interchangeable, allowing the data 
structures themselves to be used interchangeably in a majority of common use 
cases.

### Capabilities and Aspect


A capabilities and aspect based system with syntax support allows the data 
structures and algorithms to specify their interactions in a manner which 
makes composition automatic, even in the case of very dissimilar data 
structures and algorithms. This allows the seamless joinery of a common 
collection which does not require extensive manual work to create custom 
interfaces between differing structures.

Constellation's data structure description implementation is be based on Aspect 
Oriented Programming, though with a more restricted form of pointcut to permit 
full compilation and inlining of advice and to reduce the nonlocality caused by 
normal AOP. An algorithm implementation may expose pointcuts whereby additional 
operations may be composed. This allows customizing standard algorithms for a 
particular need with no extra overhead. Every data structure will expose 
pointcuts with various granularities on modifications to permit composed 
structures to update dependent structures. These must never produce a loop.
A collection may be composed of multiple data structures. These data structures 
may provide implementations of many methods. The system of advice and pointcuts 
will permit specializing the data structures and automate the process of 
cross linking data between them where necessary.

## The Data Query Language 

Featuring a Language Integrated Query (LINQ) inspired syntax the data query 
language provides tools for quickly building produce-transduce-consume chains
which may be in line with other terra code, or compiled to an object file for 
linking with C, C++, or any other language featuring a compatible ABI.

### Optimization of Queries 

Constellation Query allows the production of highly efficient in-memory queries 
through extensive inlining and indirection reduction. Constellation queries 
produce native code implementing the entire query chain in a single code block,
avoiding both the high memory usage and cache misses of intermediate arrays
and the many indirections required for chained iterators.


