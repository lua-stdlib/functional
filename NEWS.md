# std.functional NEWS - User visible changes

## Noteworthy changes in release ?.? (????-??-?) [?]


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

