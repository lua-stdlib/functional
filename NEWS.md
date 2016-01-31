# functional NEWS - User visible changes

## Noteworthy changes in release 1.0 (2016-01-31) [stable]

### New features (since lua-stdlib-41.2)

  - Initial release, now separated out from lua-stdlib.

  - `functional.memoize` uses a fast stable render based serialization
    call by default now, when the _mnemonic_ parameter is not given.

  - New `functional.operator.eqv` is similar to `functional.operator.eq`,
    except that it succeeds when recursive table contents are equivalent.

  - `functional.operator.eqv` also uses render to determine equivalence
    between tables, which means it works correctly for table key
    equivalence too.

  - Passing the result of `functional.lambda` to `tostring` returns the
    original lambda string.

  - New `functional.tuple` object, for managing interned immutable
    nil-preserving tuples:

    ```lua
    local Tuple = require "functional.tuple"
    local t3 = Tuple (nil, false, nil)
    local t3_ = Tuple (nil, false, nil)
    assert (t3 == t3_)

    local len = require "functional.operator".len
    assert (len (t3) == 3)

    local t = {}
    for i = 1, len (t3) do t = t3[i] end
    assert (len (t) == 3)

    local a, b, c = t3 ()
    assert (a == nil and b == false and c == nil)
    ```

  - New `functional.any` returns a function that calls each of the
    passed functions with the same arguments, stopping and returning the
    result from the first of those calls that does not equal `nil`.

  - New `functional.product` returns a list of combinations made by
    taking one element from each of the argument lists.  See LDocs for
    an example.

  - New `functional.operator.len` improves upon `std.table.len`.
    `functional.operator.len` is always deterministic; counting only
    numerically indexed elements immediately up to the first `nil` valued
    element (PUC-Rio Lua does not guarantee this with its `#` operator):

    ```lua
    local t1 = {1, 2, [5]=3}
    local t2 = {1, 2, nil, nil, 3}
    assert (eqv (t1, t2))
    assert (len (t1) == len (t2))
    assert (#t1 == #t2) --> PUC-Rio Lua: might be false!
    ```

  - `functional.ireverse` improves upon `std.ireverse` implementing the
    functional style of a non-destructive sequence reversing operation.

  - `functional.flatten` and `functional.shape` improve upon
    `std.table.flatten` and `std.table.shape` by being far more useful
    for functional programming style than using regular tables in
    imperative code.


### Bug fixes

  - `functional.any`, `functional.bind` and `functional.compose` return
    functions that propagate trailing `nil` arguments correctly.

  - `functional.memoize` now considers trailing nil arguments when
    looking up a memoized value for those particular arguments, and
    propagates `nil` return values from _mnemonic_ functions correctly.

  - `functional.filter`, `functional.map` and `functional.reduce` now
    pass trailing nil arguments to their iterator function correctly.


### Incompatible changes

  - `functional.lambda` no longer returns a bare function, but a functable
    that can be called and stringified.

