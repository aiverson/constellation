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
