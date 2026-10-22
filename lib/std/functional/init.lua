--[[
 Functional programming for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2002-2026 std.functional authors
]]
--[[--
 Functional programming.

 A selection of higher-order functions to enable a functional style of
 programming in Lua.

 **Load this module with `require 'std.functional.init'`.**  When
 lua-stdlib is installed, `require 'std.functional'` loads the older,
 incompatible 41.x API that it keeps under that name, and only gives you
 this module when lua-stdlib is not installed.

 Functions that iterate take their data first and their function last,
 as `table.sort` and `string.gsub` do.  The data is an *iterable*: a
 table, whose items are its values from 1 to its `n` field or length, so
 `table.pack` keeps holes; or an iterator function, whose items end
 with its first nil result, such as `s:gmatch(pat)`.  Use @{iter} to
 pass a stateless iterator, such as `iter(pairs(t))`.  The function is
 called with all the results of an iteration.  Functions that return
 several items return lists, with their length in field `n`.

 Each function documents its calling convention as a *Signature*, in the
 syntax of typecheck declarations: `|` separates alternative types, `?`
 marks an argument that may be nil, `[...]` one that may be left out
 even when others follow it, `<...>` one that may only be left out along
 with every argument after it, and `...` stands for any number more of
 the same.  So `foldl(table|function, [any], callable)` takes an
 iterable, optionally an initial value, and a function, and
 `detect(table|function, <?any>)` takes an iterable, and optionally a
 predicate.

 When an argument in `[...]` is left out, the arguments after it move up
 to take its place, so a `nil` passed there is a value.  An argument in
 `<...>` is the last that is passed, and it can be left out, or be nil,
 which are not the same where `nil` is a value to compare with: `some(t)`
 tests for anything truthy, but `some(t, nil)` tests for a nil item.

 A predicate is a plain function.  Anything else that is passed where a
 predicate is wanted, a functable such as a @{lambda} included, is a
 value to compare each item with, as `==`.  Use @{predicate} to call a
 functable instead.

 @module std.functional.init
]]


local _ENV = require 'std.normalize' {
   'coroutine.wrap',
   'coroutine.yield',
   'math.ceil',
   'std.functional._base.argscheck',
   'std.functional._base.serialize',
   'string.format',
   'table.concat',
   'table.remove',
   'table.sort',
}


--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


-- Call visit with all the results of each item of an iterable, until
-- visit returns something truthy, and then return true.  A table's items
-- are its values from 1 to its `n` field or length, so holes are
-- visited; an iterator function's items end with its first nil result.
local function walk(seq, visit)
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
         walk(n, visit)
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


-- Call a branch if it is callable, otherwise return it as it is.
local function call(branch, ...)
   if callable(branch) then
      return branch(...)
   end
   return branch
end


local function case(with, branches)
   if branches[with] ~= nil then
      return call(branches[with], with)
   end

   if type(with) == 'string' then
      for i = 1, len(branches) do
         local clause = branches[i]
         if type(clause) == 'table' and type(clause[1]) == 'string' then
            local captures = pack(with:match('^' .. clause[1] .. '$'))
            if captures[1] ~= nil then
               return call(clause[2], unpack(captures, 1, captures.n))
            end
         end
      end
   end

   return call(branches.default, with)
end


local function collect(seq)
   local r, n = {}, 0
   walk(seq, function(item)
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


local function choose(test, consequent, alternative)
   local leg = alternative
   if test then
      leg = consequent
   end
   return call(leg, test)
end


local function cond(...)
   local clauses = pack(...)
   for i = 1, clauses.n do
      local test, branch = unpack(clauses[i], 1, 2)
      if test then
         return call(branch, test)
      end
   end
end


local function contains(seq, x)
   return walk(seq, topredicate(x)) == true
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
      walk(seq, function(...)
         if choose(pred(...), passes, not passes) then
            n = n + 1
            r[n] = (...)
         end
      end)
      r.n = n
      return r
   end
end

local filter, reject = keeper(true), keeper(false)


local function flatten(t)
   return collect(flatiter(t))
end


local function foldl(seq, acc, fn)
   if fn == nil then
      fn, acc = acc, {}
   end
   walk(seq, function(...)
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
   walk(seq, function(...)
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


local function reversed(seq)
   local items = collect(seq)
   local n = items.n
   local r = {n = n}
   for i = 1, n do
      r[n - i + 1] = items[i]
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


local function converge(x, limit, fn)
   if fn == nil then
      limit, fn = 1000, limit
   end
   for _ = 1, limit do
      local r = fn(x)
      if r == x then
         return x
      end
      x = r
   end
   error(format('no convergence after %d calls', limit), 2)
end


local function indexof(seq, ...)
   local pred = topredicate(given(id, ...))
   local i, found = 0, nil
   walk(seq, function(...)
      i = i + 1
      if pred(...) then
         found = i
         return true
      end
   end)
   return found
end


local function flatmap(seq, fn)
   local r, n = {}, 0
   walk(seq, function(...)
      local items = fn(...)
      if items ~= nil then
         walk(items, function(item)
            n = n + 1
            r[n] = item
         end)
      end
   end)
   r.n = n
   return r
end


local function sorted(seq, cmp)
   cmp = default(cmp, function(a, b)
      return a < b
   end)
   local items = collect(seq)
   local decorated = {}
   for i = 1, items.n do
      decorated[i] = {items[i], i}
   end
   -- Items that neither one orders before the other keep their order.
   sort(decorated, function(a, b)
      if cmp(a[1], b[1]) then
         return true
      elseif cmp(b[1], a[1]) then
         return false
      end
      return a[2] < b[2]
   end)
   local r = {n = items.n}
   for i = 1, items.n do
      r[i] = decorated[i][1]
   end
   return r
end


local function each(seq, fn)
   walk(seq, function(...)
      fn(...)
   end)
end


local function firstof(seq, pred, fn)
   if fn == nil then
      pred, fn = id, pred
   end
   pred = topredicate(pred)
   local found
   local function test(...)
      if pred(...) then
         found = ...
         return true
      end
   end
   walk(seq, function(...)
      return test(fn(...))
   end)
   return found
end


local function detect(seq, ...)
   return firstof(seq, given(id, ...), id)
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
   walk(seq, function(...)
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
   for i = 1, len(x) do
      for j = 1, len(l) do
         r[#r + 1] = {x[i], unpack(l[j], 1, len(l[j]))}
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
   for i = 1, len(dims) do
      local v = dims[i]
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
   return walk(seq, topredicate(given(id, ...))) == true
end


local function tabulate(seq, fn)
   local r = {}
   walk(seq, function(...)
      local k, v = fn(...)
      if k ~= nil then
         r[k] = v
      end
   end)
   return r
end


local function isempty(x)
   if type(x) ~= 'table' then
      return false
   end
   local k = next(x)
   return k == nil or (k == 'n' and x.n == 0 and next(x, k) == nil)
end


local function either(x, default)
   if x == nil or isempty(x) then
      return default
   end
   return x
end


local function except(t, pred)
   pred = topredicate(pred)
   local r = {}
   for k, v in next, t do
      if not pred(k) then
         r[k] = v
      end
   end
   return r
end


local function pluck(t, keys)
   local r = {}
   walk(keys, function(k)
      local v = t[k]
      if v ~= nil then
         r[k] = v
      end
   end)
   return r
end


local function mapkeys(t, fn)
   local r = {}
   for k, v in next, t do
      local key = fn(k)
      if key ~= nil then
         r[key] = v
      end
   end
   return r
end


local function values(t)
   local r, n = {}, 0
   for _, v in next, t do
      n = n + 1
      r[n] = v
   end
   r.n = n
   return r
end


local function invert(t)
   return tabulate(iter(next, t), function(k, v)
      return v, k
   end)
end


local function zip(tt)
   local r = {}
   for outerk, inner in next, tt do
      for k, v in next, inner do
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
   --- Iterables and lists
   -- @section lists

   --- Collect the items of an iterable into a list.
   -- An iterable is a table, whose items are its values from 1 to its `n`
   -- field or its length, or an iterator function, whose items end with
   -- its first nil result.  Where an iterator function returns several
   -- values, the item is the first of them.
   -- @function collect
   -- @signature collect(table|function)
   -- @tparam table|function seq an iterable
   -- @treturn table a list of the items, with its length in field `n`
   -- @see iter
   -- @usage
   --   --> {'a', 'b', 'c', n=3}
   --   collect(iter(ipairs {'a', 'b', 'c'}))
   collect = X('collect(table|function)', collect),

   --- Call a function with each item of an iterable, for its effects.
   -- The function is called with all the results of an iteration, and
   -- every item is visited, whatever it returns.  Use @{some} or
   -- @{firstof} to stop early.
   -- @function each
   -- @signature each(table|function, callable)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @func fn function called with each item
   -- @see map
   -- @usage
   --   each(args, function(arg) print(arg) end)
   each = X('each(table|function, callable)', each),

   --- Filter the items of an iterable with a predicate.
   -- Only a plain function is a predicate; anything else, a functable
   -- included, is a value to compare each item with, as `==`.  Use
   -- @{predicate} to call a functable.  The predicate is called with all
   -- the results of an iteration, and the item kept is the first of them.
   -- @function filter
   -- @signature filter(table|function, ?any)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param pred a predicate function, or a value to compare with
   -- @treturn table a list of the items that pass, with its length in
   --    field `n`
   -- @see predicate
   -- @usage
   --   --> {2, 4, n=2}
   --   filter({1, 2, 3, 4}, function(e) return e % 2 == 0 end)
   filter = X('filter(table|function, ?any)', filter),

   --- Map a function over an iterable, and concatenate the results.
   -- *fn* is called with all the results of an iteration, and returns an
   -- iterable of items, such as a list, or nil for none.
   -- @function flatmap
   -- @signature flatmap(table|function, callable)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @func fn function returning an iterable of the items to add
   -- @treturn table a list of the items of every result, in order, with
   --    its length in field `n`
   -- @see flatten
   -- @see map
   -- @usage
   --   --> {1, 1, 2, 2, n=4}
   --   flatmap({1, 2}, function(e) return {e, e} end)
   flatmap = X('flatmap(table|function, callable)', flatmap),

   --- Flatten a nested table into a list.
   -- @function flatten
   -- @signature flatten(table)
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
   -- @signature foldl(table|function, [any], callable)
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
   -- @signature foldr(table|function, [any], callable)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param[opt={}] acc initial accumulator
   -- @func fn binary function
   -- @return the final accumulator
   -- @see foldl
   -- @usage
   --   foldr({10000, 100}, 10, operator.quot) == 10000 / (100 / 10)
   foldr = X('foldr(table|function, [any], callable)', foldr),

   --- Make an iterator function from a generic-for triple.
   -- Each call passes on all of the results of the next iteration, and
   -- they are nil once the iterator is exhausted.  Use it to pass a
   -- stateless iterator, such as `pairs(t)`, where an iterator function
   -- is wanted.
   -- @function iter
   -- @signature iter(callable, <?any...>)
   -- @func f iterator function, as in a generic `for`
   -- @param[opt] s invariant state, passed to *f* on every call
   -- @param[opt] c initial control variable
   -- @treturn function an iterator function with *s* and *c* closed over
   -- @usage
   --   --> {'a', 1}, {'b', 2}
   --   local next_pair = iter(pairs {a=1, b=2})
   iter = X('iter(callable, <?any...>)', iter),

   --- Map a function over the items of an iterable.
   -- The function is called with all the results of an iteration.
   -- @function map
   -- @signature map(table|function, callable)
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
   -- @signature map_with(table of tables, callable)
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

   --- Split the items of an iterable by a predicate.
   -- @function partition
   -- @signature partition(table|function, ?any)
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

   --- Functional list product.
   --
   -- Return a list of each combination possible by taking a single
   -- element from each of the argument lists.
   -- @function product
   -- @signature product(list...)
   -- @param ... operands
   -- @return result
   -- @usage
   --   --> {'000', '001', '010', '011', '100', '101', '110', '111'}
   --   map(product({0,1}, {0, 1}, {0, 1}), table.concat)
   product = X('product(list...)', product),

   --- Reject the items of an iterable that pass a predicate.
   -- The opposite of @{filter}.
   -- @function reject
   -- @signature reject(table|function, ?any)
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

   --- The items of an iterable in the opposite order.
   -- Unlike `ipairs`, this keeps the holes in a table, so the position
   -- of each item is as far from the end as it was from the start.
   -- @function reversed
   -- @signature reversed(table|function)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @treturn table a new list of the items in reverse order, with its
   --    length in field `n`
   -- @usage
   --   --> {'c', 'b', 'a', n=3}
   --   reversed {'a', 'b', 'c'}
   reversed = X('reversed(table|function)', reversed),

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
   -- @signature shape(table, table)
   -- @tparam table t a table of elements
   -- @tparam table dims table of dimensions `{d1, ..., dn}`
   -- @return reshaped list
   -- @usage
   --   --> {{'a', 'b'}, {'c', 'd'}, {'e', 'f'}}
   --   shape({'a', 'b', 'c', 'd', 'e', 'f'}, {3, 2})
   shape = X('shape(table, table)', shape),

   --- A sorted copy of an iterable.
   -- The sort is stable: items that neither is ordered before the other
   -- keep the order they had.
   -- @function sorted
   -- @signature sorted(table|function, <?callable>)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @func[opt] cmp function to call with two items, returning `true` if
   --    the first is ordered before the second; by default `<`
   -- @treturn table a new list of the items in order, with its length in
   --    field `n`
   -- @usage
   --   --> {1, 2, 3, n=3}
   --   sorted {3, 1, 2}
   sorted = X('sorted(table|function, <?callable>)', sorted),

   --- Zip a table of tables.
   -- Make a new table, with lists of elements at the same index in the
   -- original table. This function is effectively its own inverse.
   -- @function zip
   -- @signature zip(table of tables)
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
   -- @signature zip_with(table of tables, callable)
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

   --- Searching and predicates
   -- @section search

   --- Whether any item of an iterable matches a value or predicate.
   -- Anything but a plain function is compared with each item, as `==`,
   -- so `contains(t, nil)` asks whether *t* has a hole.  Use
   -- @{predicate} to call a functable.  Deep equality is
   -- `bind(operator.eqv, {x})`.
   -- @function contains
   -- @signature contains(table|function, ?any)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param x a value to compare with, or a predicate function
   -- @treturn boolean `true` if any item matches, otherwise `false`
   -- @see some
   -- @usage
   --   --> true
   --   contains({'a', 'b', 'c'}, 'b')
   contains = X('contains(table|function, ?any)', contains),

   --- Find the first item of an iterable that passes a predicate.
   -- The predicate is called with all the results of an iteration.  If
   -- *pred* is omitted, it passes anything truthy, as in @{some}:
   -- use `detect(seq, false)` to find `false`.
   -- An explicit `nil`, unlike leaving *pred* out, is compared with the
   -- items, as for @{contains}.
   -- @function detect
   -- @signature detect(table|function, <?any>)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param[opt] pred a predicate function, or a value to compare with
   -- @return the first item that passes, or `nil` if there isn't one
   -- @see filter
   -- @see firstof
   -- @see predicate
   -- @usage
   --   --> 'b'
   --   detect({'a', 'b', 'c'}, function(e) return e > 'a' end)
   detect = X('detect(table|function, <?any>)', detect),

   --- The first result of calling a function with each item that passes.
   -- *fn* is called with all the results of an iteration, and the
   -- predicate with all the results of that call.  The call, and so the
   -- iteration, stops at the first call that passes, and its first result
   -- is returned, so *fn* is not called for items after it.  If *pred* is
   -- omitted, it passes anything truthy.
   -- An explicit `nil` for *pred*, unlike leaving it out, is compared with
   -- the results.
   -- @function firstof
   -- @signature firstof(table|function, [?any], callable)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param[opt] pred a predicate function, or a value to compare with
   -- @func fn function to call with each item
   -- @return the first result of the first call of *fn* that passes, or
   --    `nil` if there isn't one
   -- @see detect
   -- @see some
   -- @usage
   --   --> 'two': parse is not called for items after 2
   --   firstof({1, 2, 3}, function(e) if e == 2 then return 'two' end end)
   --   --> the first file that opens
   --   firstof(paths, io.open)
   firstof = X('firstof(table|function, [?any], callable)', firstof),

   --- The position of the first item that passes a predicate.
   -- The predicate is called with all the results of an iteration.  If
   -- *pred* is omitted, it passes anything truthy, and anything
   -- that is not a function is compared with each item, as `==`.
   -- An explicit `nil`, unlike leaving *pred* out, is compared with the
   -- items, as for @{contains}.
   -- @function indexof
   -- @signature indexof(table|function, <?any>)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param[opt] pred a predicate function, or a value to compare with
   -- @treturn int|nil the position of the first item that passes, or
   --    `nil` if there isn't one
   -- @see detect
   -- @usage
   --   --> 2
   --   indexof({'a', 'b', 'c'}, 'b')
   indexof = X('indexof(table|function, <?any>)', indexof),

   --- Whether a value is a table with nothing in it.
   -- A table with only an `n` field of 0 is empty too, as the list
   -- results of this module are.
   -- @function isempty
   -- @signature isempty(?any)
   -- @param x a value
   -- @treturn boolean `true` if *x* is an empty table, otherwise `false`
   -- @see either
   -- @usage
   --   --> true, true, false
   --   isempty {}, isempty(table.pack()), isempty ''
   isempty = X('isempty(?any)', isempty),

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
   -- @signature predicate(?any)
   -- @param x a value, a function that tests a value, or a functable
   -- @treturn function a predicate for *x*
   -- @usage
   --   is_five = predicate(5)
   --   is_five(5), is_five(6) --> true, false
   --   is_even = predicate(lambda '|e| e % 2 == 0')
   predicate = X('predicate(?any)', predicate),

   --- Whether any item of an iterable passes a predicate.
   -- If *pred* is omitted, it passes anything truthy.
   -- An explicit `nil`, unlike leaving *pred* out, is compared with the
   -- items, as for @{contains}.
   -- @function some
   -- @signature some(table|function, <?any>)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @param[opt] pred a predicate function, or a value to compare with
   -- @treturn boolean `true` if any item passes, otherwise `false`
   -- @see contains
   -- @usage
   --   --> true
   --   some({false, 'x'})
   some = X('some(table|function, <?any>)', some),

   --- Tables
   -- @section tables

   --- A copy of a table without the keys that match a key or predicate.
   -- Anything but a plain function is compared with each key, as `==`.
   -- Use @{pluck} to keep keys instead.
   -- @function except
   -- @signature except(table, ?any)
   -- @tparam table t a table
   -- @param pred a predicate function to call with each key, or a key
   --    to compare with
   -- @treturn table a new table of the entries of *t* for the keys that
   --    do not match, which is empty if there are none
   -- @see pluck
   -- @see reject
   -- @usage
   --   --> {b=2, c=3}
   --   except({a=1, b=2, c=3}, 'a')
   except = X('except(table, ?any)', except),

   --- Swap the keys and values of a table.
   -- If more than one key has the same value, one of them wins.
   -- @function invert
   -- @signature invert(table)
   -- @tparam table t a table
   -- @treturn table a new table with the values of *t* for keys, and its
   --    keys for values
   -- @see tabulate
   -- @usage
   --   --> {a=1, b=2}
   --   invert {'a', 'b'}
   invert = X('invert(table)', invert),

   --- Map a function over the keys of a table.
   -- The values are kept.  If *fn* returns nil for a key, the entry is
   -- left out, and if it returns the same key for more than one, one of
   -- them wins.
   -- @function mapkeys
   -- @signature mapkeys(table, callable)
   -- @tparam table t a table
   -- @func fn map function, called with each key
   -- @treturn table a new table of the values of *t* for the results of
   --    *fn*
   -- @see mapvalues
   -- @usage
   --   --> {A=1, B=2}
   --   mapkeys({a=1, b=2}, string.upper)
   mapkeys = X('mapkeys(table, callable)', mapkeys),

   --- Map a function over the values of a table.
   -- Keys are kept.  The result of *fn* is stored as it is, so a value can
   -- map to `false`; return the value itself to pass it through, and
   -- return nil to leave the key out of the result.
   -- @function mapvalues
   -- @signature mapvalues(table, callable)
   -- @tparam table t a table
   -- @func fn map function, called with each value
   -- @treturn table a new table of the same keys, and the results of *fn*
   -- @see map
   -- @usage
   --   --> {a=2, b=4}
   --   mapvalues({a=1, b=2}, lambda '=_1 * 2')
   mapvalues = X('mapvalues(table, callable)', mapvalues),

   --- A table of just some of the entries of a table.
   -- @function pluck
   -- @signature pluck(table, table|function)
   -- @tparam table t a table
   -- @tparam table|function keys an iterable of keys, see @{collect}
   -- @treturn table a new table of the entries of *t* for those keys,
   --    leaving out any that are nil, which is empty if there are none
   -- @see except
   -- @usage
   --   --> {a=1, c=3}
   --   pluck({a=1, b=2, c=3}, {'a', 'c', 'd'})
   pluck = X('pluck(table, table|function)', pluck),

   --- Make a table from the key and value results of a function.
   -- Items for which *fn* returns a nil key are left out, and a later
   -- result for a key replaces an earlier one.
   -- @function tabulate
   -- @signature tabulate(table|function, callable)
   -- @tparam table|function seq an iterable, see @{collect}
   -- @func fn function called with all the results of an iteration, to
   --    return a key and a value
   -- @treturn table a table of the keys and values from *fn*
   -- @see map
   -- @usage
   --   --> {a=1, b=2}
   --   tabulate(iter(pairs {1, 2}), function(i, v) return ({'a', 'b'})[i], v end)
   tabulate = X('tabulate(table|function, callable)', tabulate),

   --- The values of a table.
   -- Like `table.keys` in std.normalize, the order is not specified, and
   -- every field is a value, so the `n` field of a list with a length is
   -- one too: use @{collect} to list the items of a list.
   -- @function values
   -- @signature values(table)
   -- @tparam table t a table
   -- @treturn table a list of the values of *t*, with its length in
   --    field `n`
   -- @usage
   --   --> {1, 2, n=2}, in some order
   --   values {a=1, b=2}
   values = X('values(table)', values),

   --- Functions
   -- @section functions

   --- Call a series of functions until one returns non-nil.
   -- @function any
   -- @signature any(callable...)
   -- @func ... functions to call
   -- @treturn function to call fn1 .. fnN until one returns non-nil.
   -- @usage
   --   old_object_type = any(std.object.type, io.type, type)
   any = X('any(callable...)', any),

   --- Partially apply a function.
   -- @function bind
   -- @signature bind(callable, table)
   -- @func fn function to apply partially
   -- @tparam table argt table of *fn* arguments to bind
   -- @return function with *argt* arguments already bound
   -- @usage
   --   cube = bind(std.functional.operator.pow, {[2] = 3})
   bind = X('bind(callable, table)', bind),

   --- Identify callable types.
   -- @function callable
   -- @signature callable(<?any>)
   -- @param x an object or primitive
   -- @return `true` if *x* can be called, otherwise `false`
   -- @usage
   --   if callable(functable) then functable(args) end
   callable = X('callable(<?any>)', callable),

   --- Compose functions.
   -- @function compose
   -- @signature compose(callable...)
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

   --- Call a function with a value, and then with each result, until the
   -- result is the same as the value it was called with.
   -- @function converge
   -- @signature converge(?any, [int], callable)
   -- @param x a value
   -- @int[opt=1000] limit most calls of *fn* to make
   -- @func fn function to call with *x*, and with each result
   -- @return the first value that *fn* returns unchanged
   -- @raise error `no convergence after N calls` if *fn* still changes
   --   its result after *limit* calls
   -- @usage
   --   --> 'a'
   --   converge('aaa', function(s) return (s:gsub('aa', 'a')) end)
   converge = X('converge(?any, [int], callable)', converge),

   --- Curry a function.
   -- @function curry
   -- @signature curry(callable, int)
   -- @func fn function to curry
   -- @int n number of arguments
   -- @treturn function curried version of *fn*
   -- @usage
   --   add = curry(function(x, y) return x + y end, 2)
   --   incr, decr = add(1), add(-1)
   curry = X('curry(callable, int)', curry),

   --- Identity function.
   -- @function id
   -- @signature id(<?any...>)
   -- @param ... arguments
   -- @return *arguments*
   id = id,   -- any number of any type arguments!

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
   -- @signature lambda(string)
   -- @string s a lambda string
   -- @treturn functable compiled lambda string, can be called like a function
   -- @usage
   --   -- The following are equivalent:
   --   lambda '= _1 < _2'
   --   lambda '|a,b| a<b'
   lambda = X('lambda(string)', lambda),

   --- Memoize a function, by wrapping it in a functable.
   --
   -- To ensure that memoize always returns the same results for the same
   -- arguments, it passes arguments to *fn*. You can specify a more
   -- sophisticated function if memoize should handle complicated argument
   -- equivalencies.
   -- @function memoize
   -- @signature memoize(callable, <?callable>)
   -- @func fn pure function: a function with no side effects
   -- @tparam[opt=std.tostring] mnemonic mnemonicfn how to remember the arguments
   -- @treturn functable memoized function
   -- @usage
   --   local fast = memoize(function(...) --[[ slow code ]] end)
   memoize = X('memoize(callable, <?callable>)', memoize),

   --- No operation.
   -- This function ignores all arguments, and returns no values.
   -- @function nop
   -- @signature nop(<?any...>)
   -- @see id
   -- @usage
   --   if unsupported then vtable['memrmem'] = nop end
   nop = function() end,

   --- Dispatch and selection
   -- @section dispatch

   --- A rudimentary case statement.
   -- Select a branch by matching *with* against *branches*: first as a
   -- key, then, if *with* is a string, against the patterns of the
   -- `{pattern, branch}` pairs in the array part of *branches*, in order,
   -- and last, `branches.default`.  A key counts if its branch is not
   -- nil, so a branch can be `false`.  A pattern is anchored at both
   -- ends, and its captures, or the whole match if it has none, are
   -- passed to its branch.  Integer keys share the array part with the
   -- pattern pairs, so don't use both in one table.
   -- @function case
   -- @signature case(?any, table)
   -- @param with expression to match
   -- @tparam table branches map possible matches to branches
   -- @return the branch selected, or if it is a function or functable,
   --    the result of calling it with *with* (or the captures of a
   --    matching pattern); otherwise `nil`
   -- @see cond
   -- @usage
   --   return case(type(object), {
   --      table   = 'table',
   --      string  = function() return 'string' end,
   --      default = function(s) error('unhandled type: ' .. s) end,
   --   })
   --
   --   case(arg, {
   --      {'%-%-(%w+)=(.*)', function(name, value) opts[name] = value end},
   --      {'%-(%w)', function(flag) opts[flag] = true end},
   --      default = function(s) files[#files + 1] = s end,
   --   })
   case = X('case(?any, table)', case),

   --- Select one of two values by a test.
   -- Like `test and consequent or alternative`, except that either can
   -- be `false` or `nil`.  A function or functable leg is called with
   -- *test*, and its result returned, but only if it is the one chosen,
   -- so pass anything with a side effect, or that is expensive or unsafe
   -- to compute, as a function.  To return a function itself, wrap it in
   -- one.
   -- @function choose
   -- @signature choose(?any, ?any, <?any>)
   -- @param test a value, 'truthy' or 'falsey'
   -- @param consequent chosen if *test* is truthy
   -- @param[opt] alternative chosen if it is not
   -- @return *consequent* or *alternative*, or the result of calling it
   -- @see cond
   -- @usage
   --   --> 'yes'
   --   choose(1 < 2, 'yes', 'no')
   --
   --   --> nothing is read unless the file is wanted
   --   choose(wanted, function() return io.open(path):read('a') end)
   choose = X('choose(?any, ?any, <?any>)', choose),

   --- A rudimentary condition-case statement.
   -- Each clause is a `{test, branch}` pair, and the first clause whose
   -- *test* is 'truthy' selects its *branch*, as an if/elseif chain
   -- does; use a `true` test for the last clause to make it the default.
   -- A test can be nil, which is 'falsey' like any other.
   -- @function cond
   -- @signature cond(<table...>)
   -- @tparam table ... clauses `{test, branch}` pairs
   -- @return the branch of the first clause that passes, or if it is a
   --    function or functable, the result of calling it with the *test*;
   --    otherwise `nil`
   -- @see case
   -- @usage
   --   -- recursively calculate the nth triangular number
   --   function triangle(n)
   --      return cond(
   --         {n <= 0, 0},
   --         {n == 1, 1},
   --         {true, function() return n + triangle(n - 1) end})
   --   end
   cond = X('cond(<table...>)', cond),

   --- A value, unless it is nil, then a default.
   -- Only nil is missing, so `false`, `0`, an empty string or table, and
   -- a functable such as a @{lambda}, which is an empty table, are all
   -- values that *x* can be.  Use it for an optional argument.  Unlike
   -- `either`, which is for a result that can be empty, an empty table
   -- is something.
   -- @function default
   -- @signature default(?any, <?any>)
   -- @param x a value
   -- @param[opt] d what to return if *x* is nil
   -- @return *x*, or *d*
   -- @usage
   --   cmp = default(cmp, function(a, b) return a < b end)
   default = X('default(?any, <?any>)', default),

   --- A value, unless it is nil or an empty table, then a default.
   -- Unlike `x or default`, an empty table counts as nothing, and
   -- `false` is a value like any other.
   -- @function either
   -- @signature either(?any, <?any>)
   -- @param x a value
   -- @param[opt] default what to return if *x* is nil or empty
   -- @return *x*, or *default*
   -- @see isempty
   -- @usage
   --   --> {'unix'}
   --   either({}, {'unix'})
   either = X('either(?any, <?any>)', either),
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
