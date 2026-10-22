# std.functional NEWS - User visible changes

## Noteworthy changes in release ?.? (????-??-?) [?]

### Incompatible changes

  - std.functional 2 is a new design, after `luke.functional`.  Load it
    with `require 'std.functional.init'`: when lua-stdlib 42 is
    installed, `require 'std.functional'` keeps loading the 41.x API of
    that name, and only gives you this one when lua-stdlib is not
    installed.

  - Functions that iterate take their data first and their function
    last, as `table.sort` and `string.gsub` do.  The data is an
    _iterable_: a table, whose items are its values from 1 to its `n`
    field or length, so `table.pack` keeps holes, or an iterator
    function, whose items end with its first nil result, such as
    `s:gmatch(pat)`.  There are no more `(fn, ifn, ...)` iterator
    arguments: pass a stateless iterator, such as `pairs(t)`, through
    the new `iter(pairs(t))`.  The function is called with all the
    results of an iteration.

  - `map`, `filter`, `collect`, `flatten` and `product` return lists,
    with their length in field `n`, so holes survive.  They no longer
    guess the shape of their result from how many values a function
    returns: use `tabulate` for a table of key and value results.

  - Only a plain function is a predicate.  Anything else, a functable
    such as a `lambda` included, is a value to compare each item with,
    as `==`, because functables in a sequence are usually data.  Use
    `predicate(lambda '|e| e % 2 == 0')` to call a functable.

  - `foldl` and `foldr` default their accumulator to `{}`, where 41.x
    used the first or last item, and keep it when the function returns
    nil.  `reduce` is replaced by `foldl`, which also takes iterators.

  - `case` takes the default from `branches.default`, no longer from
    `branches[1]`, and looks strings up in the `{pattern, branch}` pairs
    in its array part, in order, after the exact key.  `cond` takes
    `{test, branch}` pairs, rather than alternating arguments, so that a
    test can be nil.

    | 41.x `std.functional`                        | 2.0 `std.functional.init`            |
    | -------------------------------------------- | ------------------------------------ |
    | `map(fn, ipairs, t)`                         | `map(t, fn)`                         |
    | `map(fn, pairs, t)` with `fn` returning `k, v` | `tabulate(iter(pairs(t)), fn)`     |
    | `filter(pfn, ifn, ...)`                      | `filter(iterable, pred)`             |
    | `reduce(fn, d, ifn, ...)`                    | `foldl(iterable, d, fn)`             |
    | `foldl(fn, [d], t)`, `foldr(fn, [d], t)`     | `foldl(t, [d], fn)`, `foldr(t, [d], fn)` |
    | `collect(ifn, ...)`                          | `collect(iterable)`                  |
    | `case(with, {..., [1] = default})`           | `case(with, {..., default = default})` |
    | `cond(expr, branch, ...)`                    | `cond({expr, branch}, ...)`          |
    | `map_with(fn, tt)`, `zip_with(fn, tt)`       | `map_with(tt, fn)`, `zip_with(tt, fn)` |
    | `shape(dims, t)`                             | `shape(t, dims)`                     |

### New features

  - std.functional builds with luke instead of make.  To install
    current git master, use the `std.functional-dev-1.rockspec`:

    ```bash
    luarocks install https://raw.githubusercontent.com/lua-stdlib/functional/master/std.functional-dev-1.rockspec
    ```

  - New `each` calls a function with every item, for its effects, and
    `iter` makes an iterator function from a generic `for` triple.

  - New `reject`, `partition`, `detect`, `contains` and `some` work
    with predicates, that can be plain values to compare with, such as
    `contains(t, nil)` to ask whether `t` has a hole, and `some` and
    `detect` pass anything truthy by default.  New `firstof` returns the
    first result of calling its function with an item that passes,
    without calling it for later items.

  - New `mapvalues` maps the values of a table, keeping its keys and
    storing `false` results, and `mapkeys` maps its keys.  `tabulate`
    makes a table from the keys and values that a function returns, and
    `invert` swaps the keys and values of a table.  `pluck` makes a
    table of just some of the entries of a table, `except` one without
    the keys that match, and `values` lists the values.

  - New `isempty` says whether a table has nothing in it, and `either`
    returns its first argument unless it is nil or empty, where `x or
    default` only looks for `nil` and `false`.

  - New `predicate` makes a predicate from a value, a function or a
    functable.

  - `case` matches strings against patterns.

  - New `default` returns its first argument unless it is nil, for an
    optional argument.

### Bug fixes

  - `map` passes every result of every iteration to its function, even
    when an iterator returns `nil` before its last result.

  - `operator.concat` honours a `__concat` metamethod of either
    argument, like the `..` operator, instead of always concatenating
    the stringified arguments.

  - Every function argument that is not a predicate accepts a functable
    too, when typecheck is installed: `any`, `bind`, `compose`, `curry`,
    `foldl`, `foldr`, `map`, `map_with`, `memoize` and `zip_with` no
    longer reject the functables that `lambda` and `memoize` return.


## Noteworthy changes in release 1.0 (2026-07-26) [stable]

  - Initial support for Lua 5.5.


## Noteworthy changes in release 1.0 (2022-01-04) [stable]

### New features (since lua-stdlib-41.2)

  - Initial release, now separated out from lua-stdlib.

  - `memoize` uses a fast stable render based serialization call by
    default now, when the _mnemonic_ parameter is not given.

  - New `operator.eqv` is similar to `operator.eq`, except that it
    succeeds when recursive table contents are equivalent.

  - `operator.eqv` also uses render to determine equivalence between
    tables, which means it works correctly for table key equivalence too.

  - Passing the result of `lambda` to `tostring` returns the original
    lambda string.

  - New `tuple` object, for managing interned immutable nil-preserving
    tuples:

    ```lua
    local Tuple = require "std.functional.tuple"
    local t3 = Tuple (nil, false, nil)
    local t3_ = Tuple (nil, false, nil)
    assert (t3 == t3_)

    local len = require "std.functional.operator".len
    assert (len (t3) == 3)

    local t = {}
    for i = 1, len (t3) do t = t3[i] end
    assert (len (t) == 3)

    local a, b, c = t3 ()
    assert (a == nil and b == false and c == nil)
    ```

  - New `any` returns a function that calls each of the passed functions
    with the same arguments, stopping and returning the result from the
    first of those calls that does not equal `nil`.

  - New `product` returns a list of combinations made by taking one element
    from each of the argument lists.  See LDocs for an example.

  - New `operator.len` improves upon `std.table.len`.
    `operator.len` is always deterministic; counting only
    numerically indexed elements immediately up to the first `nil` valued
    element (PUC-Rio Lua does not guarantee this with its `#` operator):

    ```lua
    local t1 = {1, 2, [5]=3}
    local t2 = {1, 2, nil, nil, 3}
    assert (eqv (t1, t2))
    assert (len (t1) == len (t2))
    assert (#t1 == #t2) --> PUC-Rio Lua: might be false!
    ```

  - `ireverse` improves upon `std.ireverse` implementing the functional
    style of a non-destructive sequence reversing operation.

  - `flatten` and `shape` improve upon `std.table.flatten` and
    `std.table.shape` by being far more useful for functional programming
    style than using regular tables in imperative code.


### Bug fixes

  - `any`, `bind` and `compose` return functions that propagate trailing
    `nil` arguments correctly.

  - `memoize` now considers trailing nil arguments when looking up a
    memoized value for those particular arguments, and propagates `nil`
    return values from _mnemonic_ functions correctly.

  - `filter`, `map` and `reduce` now pass trailing nil arguments to their
    iterator function correctly.


### Incompatible changes

  - `lambda` no longer returns a bare function, but a functable that can be
    called and stringified.

