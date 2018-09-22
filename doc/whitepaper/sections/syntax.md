# Constellation Syntax 

## Motivating Example 

In this section we'll have a look at a couple of examples of what a solution 
written in Constellation might look like.

### A Simple Example

Suppose that we have a bunch of stock data in a map which is keyed on dates 
pointing to data structures containing information about various stocks. We 
to get a list of unique ticker symbols in our data set.

```Lua

function get_tickers(stock_data)
	local set, list = {}, {}
	for _, v in ipairs(stock_data) do set[v.ticker] = true end
	for name, _ in pairs(set) do table.insert(list, name) end
	return list
end
```

With Constellation we might express the same functionality as:

```
	local ticker_symbols = from d in stock_data unique d.ticker end 
```

Obviously the latter case is faster to type. Additionally, due to some 
optimization steps which can be applied generally to these sorts of queries 
Constellation can also produce code which is likely to run faster than the 
manual implementation.

### A Slightly Complicated Example 

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

This code illustrates the ease with which Constellation queries and data 
structure definitions may be composed. The operations in each of the statements
are inlined, and indirection removed where possible, before the code is 
compiled, ensuring that higher performance is achieved than would have been 
with multiple loops calling out to other functions to perform grouping and 
reduction.
