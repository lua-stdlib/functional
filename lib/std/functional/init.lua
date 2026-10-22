--[[
 Functional programming for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2002-2026 std.functional authors
]]
--[[--
 Functional programming.

 A selection of higher-order functions to enable a functional style of
 programming in Lua.

 @module std.functional
]]


local _ENV = require 'std.normalize' {
   'coroutine.wrap',
   'coroutine.yield',
   'math.ceil',
   'std.functional._base.argscheck',
   'std.functional._base.serialize',
   'table.concat',
   'table.remove',
}


local function ielems(t)
   -- capture ipairs iterator initial state
   local fn, istate, ctrl = ipairs(t)
   return function(state, _)
      local v
      ctrl, v = fn(state, ctrl)
      if ctrl then
         return v
      end
   end, istate, true -- wrapped initial state
end


--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


-- Call visit with all the results of each item of an iterable, until
-- visit returns something truthy, and then return true.  A table's items
-- are its values from 1 to its `n` field or length, so holes are
-- visited; an iterator function's items end with its first nil result.
local function each(seq, visit)
   if type(seq) == 'function' then
      local function loop(...)
         if ... ~= nil then
            if visit(...) then
               return true
            end
            return loop(seq())
         end
      end
      return loop(seq())
   end
   for i = 1, seq.n or len(seq) do
      if visit(seq[i]) then
         return true
      end
   end
end


local function isnonnil(x)
   return x ~= nil
end


local function topredicate(x)
   if type(x) == 'function' then
      return x
   end
   return function(y)
      return y == x
   end
end


-- An iterator function over the flat sequence of what *t* holds, in
-- order: it goes into the tables among its elements, and gives what they
-- hold instead.  It is what flatten collects.  (Unlike `ielems`, it does
-- not stop at a table, and unlike `Tree.leaves`, it gives no paths.)
local function flatiter(t)
   local function visit(n)
      if type(n) == 'table' then
         each(n, visit)
      else
         yield(n)
      end
   end
   return wrap(function() visit(t) end)
end


local function default(x, d)
   if x == nil then
      return d
   end
   return x
end


-- The first of *...*, even if it is nil, or else *d* if there is none.
local function given(d, ...)
   if select('#', ...) == 0 then
      return d
   end
   return (...)
end


local function any(...)
   local fns = pack(...)

   return function(...)
      local argt = {n = 0}
      for i = 1, fns.n do
         argt = pack(fns[i](...))
         if argt[1] ~= nil then
            return unpack(argt, 1, argt.n)
         end
      end
      return unpack(argt, 1, argt.n)
   end
end


local ceil = ceil -- FIXME: specl-14.x breaks function environments here :(

local function bind(fn, bound)
   return function(...)
      local argt, unbound = {}, pack(...)

      -- Inline `argt = copy(bound)`...
      local n = bound.n or 0
      for k, v in next, bound do
         -- ...but only copy integer keys.
         if type(k) == 'number' and ceil(k) == k then
            argt[k] = v
            n = k > n and k or n   -- Inline `n = maxn(unbound)` in same pass.
         end
      end

      -- Bind *unbound* parameters sequentially into *argt* gaps.
      local i = 1
      for j = 1, unbound.n do
         while argt[i] ~= nil do
            i = i + 1
         end
         argt[i], i = unbound[j], i + 1
      end

      -- Even if there are gaps remaining above *i*, pass at least *n* args.
      if n >= i then
         return fn(unpack(argt, 1, n))
      end

      -- Otherwise, we filled gaps beyond *n*, and pass that many args.
      return fn(unpack(argt, 1, i - 1))
   end
end


-- No need to recurse because functables are second class citizens in
-- Lua:
-- func=function() print 'called' end
-- func() --> 'called'
-- functable=setmetatable({}, {__call=func})
-- functable() --> 'called'
-- nested=setmetatable({}, {__call=functable})
-- nested()
-- --> stdin:1: attempt to call a table value(global 'd')
-- --> stack traceback:
-- -->	stdin:1: in main chunk
-- -->		[C]: in ?
local function callable(x)
   if type(x) == 'function' then
      return x
   end
   return (getmetatable(x) or {}).__call
end


local function case(with, branches)
   local match = branches[with] or branches[1]
   if callable(match) then
      return match(with)
   end
   return match
end


local function collect(seq)
   local r, n = {}, 0
   each(seq, function(item)
      n = n + 1
      r[n] = item
   end)
   r.n = n
   return r
end


local function compose(...)
   local fns = pack(...)

   return function(...)
      local argt = pack(...)
      for i = 1, fns.n do
         argt = pack(fns[i](unpack(argt, 1, argt.n)))
      end
      return unpack(argt, 1, argt.n)
   end
end


local function cond(expr, branch, ...)
   if branch == nil and select('#', ...) == 0 then
      expr, branch = true, expr
   end
   if expr then
      if callable(branch) then
         return branch(expr)
      end
      return branch
   end
   return cond(...)
end


local function contains(seq, x)
   return each(seq, topredicate(x)) == true
end


local function curry(fn, n)
   if n <= 1 then
      return fn
   else
      return function(x)
         return curry(bind(fn, {x}), n - 1)
      end
   end
end


-- A function to list the items of an iterable that pass a predicate, or
-- those that fail it.
local function keeper(passes)
   return function(seq, pred)
      pred = topredicate(pred)
      local r, n = {}, 0
      each(seq, function(...)
         if not pred(...) == not passes then
            n = n + 1
            r[n] = (...)
         end
      end)
      r.n = n
      return r
   end
end

local filter, reject = keeper(true), keeper(false)


local function detect(seq, pred, fn)
   pred = topredicate(default(pred, isnonnil))
   local found
   local function test(...)
      if pred(...) then
         found = ...
         return true
      end
   end
   each(seq, fn and function(...) return test(fn(...)) end or test)
   return found
end


local function flatten(t)
   return collect(flatiter(t))
end


local function foldl(seq, acc, fn)
   if fn == nil then
      fn, acc = acc, {}
   end
   each(seq, function(...)
      local r = fn(acc, ...)
      if r ~= nil then
         acc = r
      end
   end)
   return acc
end


local function partition(seq, pred)
   pred = topredicate(pred)
   local pass, fail, np, nf = {}, {}, 0, 0
   each(seq, function(...)
      if pred(...) then
         np = np + 1
         pass[np] = (...)
      else
         nf = nf + 1
         fail[nf] = (...)
      end
   end)
   pass.n, fail.n = np, nf
   return pass, fail
end


-- Be careful to reverse only the valid sequence part of a table.
local function ireverse(t)
   local oob = 1
   while t[oob] ~= nil do
      oob = oob + 1
   end

   local r = {}
   for i = 1, oob - 1 do
      r[oob - i] = t[i]
   end
   return r
end


local function foldr(seq, acc, fn)
   if fn == nil then
      fn, acc = acc, {}
   end
   local t = collect(seq)
   for i = t.n, 1, -1 do
      local r = fn(t[i], acc)
      if r ~= nil then
         acc = r
      end
   end
   return acc
end


local function id(...)
   return ...
end


local function iter(f, s, c)
   -- Take the control variable from the first result, and pass them all on.
   local function step(...)
      c = ...
      return ...
   end
   return function()
      return step(f(s, c))
   end
end


local function multiserialize(...)
   local seq = pack(...)
   local buf = {}
   for i = 1, seq.n do
      buf[i] = serialize(seq[i])
   end
   return concat(buf, ',')
end


local function memoize(fn, mnemonic)
   mnemonic = mnemonic or multiserialize

   return setmetatable({}, {
      __call = function(self, ...)
         local k = mnemonic(...)
         local t = self[k]
         if t == nil then
            t = pack(fn(...))
            self[k] = t
         end
         return unpack(t, 1, t.n)
      end
   })
end


local lambda = memoize(function(s)
   local expr

   -- Support '|args|expression' format.
   local args, body = s:match '^%s*|%s*([^|]*)|%s*(.+)%s*$'
   if args and body then
      expr = 'return function(' .. args .. ') return ' .. body .. ' end'
   end

   -- Support 'expression' format.
   if not expr then
      body = s:match '^%s*(_.*)%s*$' or s:match '^=%s*(.+)%s*$'
      if body then
         expr = [[
            return function(...)
               local _1,_2,_3,_4,_5,_6,_7,_8,_9 = ...
	       local _ = _1
	       return ]] .. body .. [[
            end
         ]]
      end
   end

   local ok, fn
   if expr then
      ok, fn = pcall(load(expr))
   end

   -- Diagnose invalid input.
   if not ok then
      return nil, "invalid lambda string '" .. s .. "'"
   end

   return setmetatable({}, {
      _type = 'Lambda',   -- as std.prototype tags its objects
      _fn = fn,           -- for predicate to unwrap
      __call = function(self, ...) return fn(...) end,
      __tostring = function(self) return s end,
   })
end, id)


local function map(seq, fn)
   local r, n = {}, 0
   each(seq, function(...)
      n = n + 1
      r[n] = (fn(...))
   end)
   r.n = n
   return r
end


local function mapvalues(t, fn)
   local r = {}
   for k, v in next, t do
      r[k] = fn(v)
   end
   return r
end


local function map_with(tt, fn)
   local r = {}
   for k, v in next, tt do
      r[k] = fn(unpack(v, 1, len(v)))
   end
   return r
end


local function predicate(x)
   local mt = getmetatable(x)
   if type(mt) == 'table' and mt._type == 'Lambda' then
      return mt._fn
   elseif type(x) ~= 'function' and callable(x) then
      return function(...)
         return x(...)
      end
   end
   return topredicate(x)
end


local function _product(x, l)
   local r = {}
   for v1 in ielems(x) do
      for v2 in ielems(l) do
         r[#r + 1] = {v1, unpack(v2, 1, len(v2))}
      end
   end
   r.n = #r
   return r
end

local function product(...)
   local argt = {...}
   if not next(argt) then
      return {n = 0}
   else
      -- Accumulate a list of products, starting by popping the last
      -- argument and making each member a one element list.
      local d = map(remove(argt), lambda '={_1}')
      -- Right associatively fold in remaining argt members.
      return foldr(argt, d, _product)
   end
end


local function shape(t, dims)
   t = flatten(t)
   -- Check the shape and calculate the size of the zero, if any
   local size = 1
   local zero
   for i, v in ipairs(dims) do
      if v == 0 then
         if zero then -- bad shape: two zeros
            return nil
         else
            zero = i
         end
      else
         size = size * v
      end
   end
   if zero then
      dims[zero] = ceil(len(t) / size)
   end
   local function fill(i, d)
      if d > len(dims) then
         return t[i], i + 1
      else
         local r = {}
         for j = 1, dims[d] do
            local e
            e, i = fill(i, d + 1)
            r[#r + 1] = e
         end
         return r, i
      end
   end
   return(fill(1, 1))
end


local function some(seq, ...)
   return each(seq, topredicate(given(id, ...))) == true
end


local function tabulate(seq, fn)
   local r = {}
   each(seq, function(...)
      local k, v = fn(...)
      if k ~= nil then
         r[k] = v
      end
   end)
   return r
end


local function zip(tt)
   local r = {}
   for outerk, inner in pairs(tt) do
      for k, v in pairs(inner) do
         r[k] = r[k] or {}
         r[k][outerk] = v
      end
   end
   return r
end


local function zip_with(tt, fn)
   return map_with(zip(tt), fn)
end


--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


local function X(decl, fn)
   return argscheck('std.functional.' .. decl, fn)
end

return {
   --- Call a series of functions until one returns non-nil.
   -- @function any
   -- @func ... functions to call
   -- @treturn function to call fn1 .. fnN until one returns non-nil.
   -- @usage
   --   old_object_type = any(std.object.type, io.type, type)
   any = X('any(callable...)', any),

   --- Partially apply a function.
   -- @function bind
   -- @func fn function to apply partially
   -- @tparam table argt table of *fn* arguments to bind
   -- @return function with *argt* arguments already bound
   -- @usage
   --   cube = bind(std.functional.operator.pow, {[2] = 3})
   bind = X('bind(callable, table)', bind),

   --- Identify callable types.
   -- @function callable
   -- @param x an object or primitive
   -- @return `true` if *x* can be called, otherwise `false`
   -- @usage
   --   if callable(functable) then functable(args) end
   callable = X('callable([?any])', callable),

   --- A rudimentary case statement.
   -- Match *with* against keys in *branches* table.
   -- @function case
   -- @param with expression to match
   -- @tparam table branches map possible matches to functions
   -- @return the value associated with a matching key, or the first non-key
   --    value if no key matches. Function or functable valued matches are
   --    called using *with* as the sole argument, and the result of that call
   --    returned; otherwise the matching value associated with the matching
   --    key is returned directly; or else `nil` if there is no match and no
   --    default.
   -- @see cond
   -- @usage
   --   return case(type(object), {
   --      table  = 'table',
   --      string = function() return 'string' end,
   --               function(s) error('unhandled type: ' .. s) end,
   --   })
   case = X('case(?any, #table)', case),

   --- Collect the items of an iterable into a list.
   -- An iterable is a table, whose items are its values from 1 to its `n`
   -- field or its length, or an iterator function, whose items end with
   -- its first nil result.  Where an iterator function returns several
   -- values, the item is the first of them.
   -- @function collect
   -- @tparam table|function seq an iterable
   -- @treturn table a list of the items, with its length in field `n`
   -- @see iter
   -- @usage
   --   --> {'a', 'b', 'c', n=3}
   --   collect(iter(ipairs {'a', 'b', 'c'}))
   collect = X('collect(table|function)', collect),

   --- Compose functions.
   -- @function compose
   -- @func ... functions to compose
   -- @treturn function composition of fnN .. fn1: note that this is the
   -- reverse of what you might expect, but means that code like:
   --
   --     compose(function(x) return f(x) end,
   --                        function(x) return g(x) end))
   --
   -- can be read from top to bottom.
   -- @usage
   --   vpairs = compose(table.invert, ipairs)
   --   for v, i in vpairs {'a', 'b', 'c'} do process(v, i) end
   compose = X('compose(callable...)', compose),

   --- A rudimentary condition-case statement.
   -- If *expr* is 'truthy' return *branch* if given, otherwise *expr*
   -- itself. If the return value is a function or functable, then call it
   -- with *expr* as the sole argument and return the result; otherwise
   -- return it explicitly.   If *expr* is 'falsey', then recurse with the
   -- first two arguments stripped.
   -- @function cond
   -- @param expr a Lua expression
   -- @param branch a function, functable or value to use if *expr* is
   --    'truthy'
   -- @param ... additional arguments to retry if *expr* is 'falsey'
   -- @see case
   -- @usage
   --   -- recursively calculate the nth triangular number
   --   function triangle(n)
   --      return cond(
   --         n <= 0, 0,
   --         n == 1, 1,
   --                 function() return n + triangle(n - 1) end)
   --   end
   cond = cond, -- any number of any type arguments!

   --- Whether any item of an iterable matches a value or predicate.
   -- Anything but a plain function is compared with each item, as `==`,
   -- so `contains(t, nil)` asks whether *t* has a hole.  Use
   -- @{predicate} to call a functable.  Deep equality is
   -- `bind(operator.eqv, {x})`.
   -- @function contains
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param x a value to compare with, or a predicate function
   -- @treturn boolean `true` if any item matches, otherwise `false`
   -- @see some
   -- @usage
   --   --> true
   --   contains({'a', 'b', 'c'}, 'b')
   contains = X('contains(table|function, ?any)', contains),

   --- Curry a function.
   -- @function curry
   -- @func fn function to curry
   -- @int n number of arguments
   -- @treturn function curried version of *fn*
   -- @usage
   --   add = curry(function(x, y) return x + y end, 2)
   --   incr, decr = add(1), add(-1)
   curry = X('curry(callable, int)', curry),

   --- A value, unless it is nil, then a default.
   -- Only nil is missing, so `false`, `0`, an empty string or table, and
   -- a functable such as a @{lambda}, which is an empty table, are all
   -- values that *x* can be.  Use it for an optional argument.  Unlike
   -- `either`, which is for a result that can be empty, an empty table
   -- is something.
   -- @function default
   -- @param x a value
   -- @param[opt] d what to return if *x* is nil
   -- @return *x*, or *d*
   -- @usage
   --   cmp = default(cmp, function(a, b) return a < b end)
   default = X('default(?any, [?any])', default),

   --- Find the first item of an iterable that passes a predicate.
   -- With *fn*, each item is mapped to the results of *fn* lazily, and
   -- the first of the first results that pass is returned, so *fn* is
   -- not called for items after it.  The predicate is called with all
   -- the results of an iteration.  If *pred* is omitted or nil, it
   -- passes anything that is not nil.
   -- @function detect
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param[opt] pred a predicate function, or a value to compare with
   -- @func[opt] fn map function
   -- @return the first item, or result of *fn*, that passes, or `nil`
   --    if there isn't one
   -- @see filter
   -- @see predicate
   -- @usage
   --   --> 'b'
   --   detect({'a', 'b', 'c'}, function(e) return e > 'a' end)
   --   --> 4, without calling `parse` for items after 4
   --   detect(args, nil, parse)
   detect = X('detect(table|function, [?any], [callable])', detect),

   --- Filter the items of an iterable with a predicate.
   -- Only a plain function is a predicate; anything else, a functable
   -- included, is a value to compare each item with, as `==`.  Use
   -- @{predicate} to call a functable.  The predicate is called with all
   -- the results of an iteration, and the item kept is the first of them.
   -- @function filter
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param pred a predicate function, or a value to compare with
   -- @treturn table a list of the items that pass, with its length in
   --    field `n`
   -- @see predicate
   -- @usage
   --   --> {2, 4, n=2}
   --   filter({1, 2, 3, 4}, function(e) return e % 2 == 0 end)
   filter = X('filter(table|function, ?any)', filter),

   --- Flatten a nested table into a list.
   -- @function flatten
   -- @tparam table t a table
   -- @treturn table a list of all non-table elements of *t*
   -- @usage
   --   --> {1, 2, 3, 4, 5}
   --   flatten {{1, {{2}, 3}, 4}, 5}
   flatten = X('flatten(table)', flatten),

   --- Fold a binary function left associatively.
   -- Call *fn* with the accumulator and all the results of each
   -- iteration, from the left.  If *fn* returns nil, the accumulator is
   -- left as it was.
   -- @function foldl
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param[opt={}] acc initial accumulator
   -- @func fn binary function
   -- @return the final accumulator
   -- @see foldr
   -- @usage
   --   foldl({10000, 100, 10}, 1000000, operator.quot) ==
   --      ((1000000 / 10000) / 100) / 10
   foldl = X('foldl(table|function, [any], callable)', foldl),

   --- Fold a binary function right associatively.
   -- Call *fn* with each item and the accumulator, from the right.  An
   -- iterator function is collected into a list first, and so only its
   -- first result of each iteration is passed on.  If *fn* returns nil,
   -- the accumulator is left as it was.
   -- @function foldr
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param[opt={}] acc initial accumulator
   -- @func fn binary function
   -- @return the final accumulator
   -- @see foldl
   -- @usage
   --   foldr({10000, 100}, 10, operator.quot) == 10000 / (100 / 10)
   foldr = X('foldr(table|function, [any], callable)', foldr),

   --- Identity function.
   -- @function id
   -- @param ... arguments
   -- @return *arguments*
   id = id,   -- any number of any type arguments!

   --- Make an iterator function from a generic-for triple.
   -- Each call passes on all of the results of the next iteration, and
   -- they are nil once the iterator is exhausted.  Use it to pass a
   -- stateless iterator, such as `pairs(t)`, where an iterator function
   -- is wanted.
   -- @function iter
   -- @func f iterator function, as in a generic `for`
   -- @param[opt] s invariant state, passed to *f* on every call
   -- @param[opt] c initial control variable
   -- @treturn function an iterator function with *s* and *c* closed over
   -- @usage
   --   --> {'a', 1}, {'b', 2}
   --   local next_pair = iter(pairs {a=1, b=2})
   iter = X('iter(callable, [?any...])', iter),

   --- Return a new sequence with element order reversed.
   --
   -- Apart from the order of the elements returned, this function follows
   -- the same rules as @{ipairs} for determining first and last elements.
   -- @function ireverse
   -- @tparam table t a table
   -- @treturn table a new table with integer keyed elements in reverse
   --    order with respect to *t*
   -- @see ipairs
   -- @usage
   --   --> bar
   --   --> foo
   --   map(ireverse {'foo', 'bar', [4]='baz', d=5}, print)
   ireverse = X('ireverse(table)', ireverse),

   --- Compile a lambda string into a Lua function.
   --
   -- A valid lambda string takes one of the following forms:
   --
   --    1. `'=expression'`: equivalent to `function(...) return expression end`
   --    1. `'|args|expression'`: equivalent to `function(args) return expression end`
   --
   -- The first form (starting with `'='`) automatically assigns the first
   -- nine arguments to parameters `'_1'` through `'_9'` for use within the
   -- expression body.   The parameter `'_1'` is aliased to `'_'`, and if the
   -- first non-whitespace of the whole expression is `'_'`, then the
   -- leading `'='` can be omitted.
   --
   -- The results are memoized, so recompiling a previously compiled
   -- lambda string is extremely fast.
   -- @function lambda
   -- @string s a lambda string
   -- @treturn functable compiled lambda string, can be called like a function
   -- @usage
   --   -- The following are equivalent:
   --   lambda '= _1 < _2'
   --   lambda '|a,b| a<b'
   lambda = X('lambda(string)', lambda),

   --- Map a function over the items of an iterable.
   -- The function is called with all the results of an iteration.
   -- @function map
   -- @tparam table|function seq an iterable, see @{collect}
   -- @func fn map function
   -- @treturn table a list of the first result of *fn* for each item,
   --    holes kept, with its length in field `n`
   -- @see filter
   -- @see map_with
   -- @see zip
   -- @usage
   --   --> {1, 4, 9, 16, n=4}
   --   map({1, 2, 3, 4}, lambda '=_1*_1')
   map = X('map(table|function, callable)', map),

   --- Map a function over a table of argument lists.
   -- @function map_with
   -- @tparam table tt a table of *fn* argument lists
   -- @func fn map function
   -- @treturn table new table of *fn* results
   -- @see map
   -- @see zip_with
   -- @usage
   --   --> {'123', '45'}, {a='123', b='45'}
   --   conc = bind(map_with, {[2] = lambda '|...|table.concat {...}'})
   --   conc {{1, 2, 3}, {4, 5}}, conc {a={1, 2, 3, x='y'}, b={4, 5, z=6}}
   map_with = X('map_with(table of tables, callable)', map_with),

   --- Map a function over the values of a table.
   -- Keys are kept.  The result of *fn* is stored as it is, so a value can
   -- map to `false`; return the value itself to pass it through, and
   -- return nil to leave the key out of the result.
   -- @function mapvalues
   -- @tparam table t a table
   -- @func fn map function, called with each value
   -- @treturn table a new table of the same keys, and the results of *fn*
   -- @see map
   -- @usage
   --   --> {a=2, b=4}
   --   mapvalues({a=1, b=2}, lambda '=_1 * 2')
   mapvalues = X('mapvalues(table, callable)', mapvalues),

   --- Memoize a function, by wrapping it in a functable.
   --
   -- To ensure that memoize always returns the same results for the same
   -- arguments, it passes arguments to *fn*. You can specify a more
   -- sophisticated function if memoize should handle complicated argument
   -- equivalencies.
   -- @function memoize
   -- @func fn pure function: a function with no side effects
   -- @tparam[opt=std.tostring] mnemonic mnemonicfn how to remember the arguments
   -- @treturn functable memoized function
   -- @usage
   --   local fast = memoize(function(...) --[[ slow code ]] end)
   memoize = X('memoize(callable, [?callable])', memoize),

   --- No operation.
   -- This function ignores all arguments, and returns no values.
   -- @function nop
   -- @see id
   -- @usage
   --   if unsupported then vtable['memrmem'] = nop end
   nop = function() end,

   --- Functional list product.
   --
   -- Return a list of each combination possible by taking a single
   -- element from each of the argument lists.
   -- @function product
   -- @param ... operands
   -- @return result
   -- @usage
   --   --> {'000', '001', '010', '011', '100', '101', '110', '111'}
   --   map(product({0,1}, {0, 1}, {0, 1}), table.concat)
   product = X('product(list...)', product),

   --- Split the items of an iterable by a predicate.
   -- @function partition
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param pred a predicate function, or a value to compare with
   -- @treturn table a list of the items that pass, with its length in
   --    field `n`
   -- @treturn table a list of the items that fail, likewise
   -- @see filter
   -- @see reject
   -- @usage
   --   --> {2, 4, n=2}, {1, 3, n=2}
   --   partition({1, 2, 3, 4}, function(e) return e % 2 == 0 end)
   partition = X('partition(table|function, ?any)', partition),

   --- Make a predicate from a value, a function or a functable.
   -- A plain function is returned as is, and a @{lambda} is unwrapped to
   -- the function inside it, so that its source string can no longer be
   -- recovered.  Any other callable is wrapped in a plain function that
   -- calls it, since it may use its own table when it is called.
   -- Anything else becomes a test for equality (as `==`, so honouring
   -- `__eq`) with it, including `nil`.
   --
   -- Functions that take a predicate, or a value to test for, treat a
   -- plain function as the predicate and everything else, a functable
   -- included, as a value, because functables in a sequence are usually
   -- data: a std.prototype object, for example, is callable.  Pass
   -- `predicate(functable)` to use a functable as the predicate instead,
   -- and to search for a function value, use `bind(operator.eq, {f})`.
   -- For deep equality use `bind(operator.eqv, {x})`.
   -- @function predicate
   -- @param x a value, a function that tests a value, or a functable
   -- @treturn function a predicate for *x*
   -- @usage
   --   is_five = predicate(5)
   --   is_five(5), is_five(6) --> true, false
   --   is_even = predicate(lambda '|e| e % 2 == 0')
   predicate = X('predicate(?any)', predicate),

   --- Reject the items of an iterable that pass a predicate.
   -- The opposite of @{filter}.
   -- @function reject
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param pred a predicate function, or a value to compare with
   -- @treturn table a list of the items that fail, with its length in
   --    field `n`
   -- @see filter
   -- @see partition
   -- @usage
   --   --> {1, 3, n=2}
   --   reject({1, 2, 3, 4}, function(e) return e % 2 == 0 end)
   reject = X('reject(table|function, ?any)', reject),

   --- Shape a table according to a list of dimensions.
   --
   -- Dimensions are given outermost first and items from the original
   -- list are distributed breadth first; there may be one 0 indicating
   -- an indefinite number. Hence, `{0}` is a flat list,
   -- `{1}` is a singleton, `{2, 0}` is a list of
   -- two lists, and `{0, 2}` is a list of pairs.
   --
   -- Algorithm: turn shape into all positive numbers, calculating
   -- the zero if necessary and making sure there is at most one;
   -- recursively walk the shape, adding empty tables until the bottom
   -- level is reached at which point add table items instead, using a
   -- counter to walk the flattened original list.
   --
   -- @todo Use ileaves instead of flatten (needs a while instead of a
   -- for in fill function)
   -- @function shape
   -- @tparam table t a table of elements
   -- @tparam table dims table of dimensions `{d1, ..., dn}`
   -- @return reshaped list
   -- @usage
   --   --> {{'a', 'b'}, {'c', 'd'}, {'e', 'f'}}
   --   shape({'a', 'b', 'c', 'd', 'e', 'f'}, {3, 2})
   shape = X('shape(table, table)', shape),

   --- Whether any item of an iterable passes a predicate.
   -- If *pred* is omitted, it passes anything truthy.
   -- An explicit `nil`, unlike leaving *pred* out, is compared with the
   -- items, as for @{contains}.
   -- @function some
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param[opt] pred a predicate function, or a value to compare with
   -- @treturn boolean `true` if any item passes, otherwise `false`
   -- @see contains
   -- @usage
   --   --> true
   --   some({false, 'x'})
   some = X('some(table|function, [?any])', some),

   --- Make a table from the key and value results of a function.
   -- Items for which *fn* returns a nil key are left out, and a later
   -- result for a key replaces an earlier one.
   -- @function tabulate
   -- @tparam table|function seq an iterable, see @{collect}
   -- @func fn function called with all the results of an iteration, to
   --    return a key and a value
   -- @treturn table a table of the keys and values from *fn*
   -- @see map
   -- @usage
   --   --> {a=1, b=2}
   --   tabulate(iter(pairs {1, 2}), function(i, v) return ({'a', 'b'})[i], v end)
   tabulate = X('tabulate(table|function, callable)', tabulate),

   --- Zip a table of tables.
   -- Make a new table, with lists of elements at the same index in the
   -- original table. This function is effectively its own inverse.
   -- @function zip
   -- @tparam table tt a table of tables
   -- @treturn table new table with lists of elements of the same key
   --    from *tt*
   -- @see map
   -- @see zip_with
   -- @usage
   --   --> {{1, 3, 5}, {2, 4}}, {a={x=1, y=3, z=5}, b={x=2, y=4}}
   --   zip {{1, 2}, {3, 4}, {5}}, zip {x={a=1, b=2}, y={a=3, b=4}, z={a=5}}
   zip = X('zip(table of tables)', zip),

   --- Zip a list of tables together with a function.
   -- @function zip_with
   -- @tparam table tt table of tables
   -- @tparam function fn function
   -- @treturn table a new table of results from calls to *fn* with arguments
   --    made from all elements the same key in the original tables; effectively
   --    the 'columns' in a simple list
   -- of lists.
   -- @see map_with
   -- @see zip
   -- @usage
   --   --> {'135', '24'}, {a='1', b='25'}
   --   conc = bind(zip_with, {[2] = lambda '|...|table.concat {...}'})
   --   conc {{1, 2}, {3, 4}, {5}}, conc {{a=1, b=2}, x={a=3, b=4}, {b=5}}
   zip_with = X('zip_with(table of tables, callable)', zip_with),
}


--- Types
-- @section Types


--- Signature of a @{memoize} argument normalization callback function.
-- @function mnemonic
-- @param ... arguments
-- @treturn string stable serialized arguments
-- @usage
--   local mnemonic = function(name, value, props) return name end
--   local intern = memoize(mksymbol, mnemonic)
