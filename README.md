Functional Programming with Lua
===============================

Copyright (C) 2002-2026 [std.functional authors][authors]

[![License](http://img.shields.io/:license-mit-blue.svg)](https://mit-license.org/2002)
[![workflow status](https://github.com/lua-stdlib/functional/actions/workflows/spec.yml/badge.svg?branch=master)](https://github.com/lua-stdlib/functional/actions)
[![codecov.io](https://codecov.io/gh/lua-stdlib/functional/graph/badge.svg?branch=master)](https://codecov.io/gh/lua-stdlib/functional?branch=master)


This is a collection of Functional Programming libraries for Lua 5.1
(including LuaJIT), 5.2, 5.3, 5.4 and 5.5. The libraries are copyright by their
authors (see the [AUTHORS][] file for details), and released under the
[MIT license][mit] (the same license as Lua itself). There is no warranty.

_std.functional_ needs only [std.normalize][normalize] beyond a standard Lua
system, though it will take advantage of [strict][] and [typecheck][] if they
are installed.

**Load std.functional 2 with `require 'std.functional.init'`.** When
[lua-stdlib][stdlib] is installed, `require 'std.functional'` loads the
older, incompatible API of lua-stdlib 41.x that it keeps under that name,
and only gives you this library when lua-stdlib is not installed:

```lua
    local functional = require 'std.functional.init'
    local map, filter = functional.map, functional.filter

    --> {2, 4, n=2}
    filter(map({1, 2, 3, 4}, function(e) return e * 2 end),
       function(e) return e < 6 end)
```

See the [NEWS][] for how to migrate from lua-stdlib 41.x.

[authors]: https://github.com/lua-stdlib/functional/blob/master/AUTHORS.md
[github]: https://github.com/lua-stdlib/functional/ "Github repository"
[lua]: https://www.lua.org "The Lua Project"
[mit]: https://mit-license.org "MIT License"
[news]: https://github.com/lua-stdlib/functional/blob/master/NEWS.md
[normalize]: https://github.com/lua-stdlib/normalize "normalized Lua APIs"
[stdlib]: https://github.com/lua-stdlib/lua-stdlib "Standard Lua Libraries"
[strict]: https://github.com/lua-stdlib/strict "strict variables"
[typecheck]: https://github.com/gvvaughan/typecheck "function type checks"


Installation
------------

The simplest and best way to install std.functional is with [LuaRocks][]. To
install the latest release):

```bash
    luarocks install std.functional
```

To install current git master (for testing, before submitting a bug
report for example):

```bash
    luarocks install https://raw.githubusercontent.com/lua-stdlib/functional/master/std.functional-dev-1.rockspec
```

The best way to install without [LuaRocks][] is to copy the `std/functional`
folder and its contents into a directory on your package search path.

[luarocks]: https://www.luarocks.org "Lua package manager"


Documentation
-------------

The latest release of these libraries is [documented in LDoc][github.io].
Pre-built HTML files are included in the release.

[github.io]: https://lua-stdlib.github.io/functional


Bug reports and code contributions
----------------------------------

These libraries are written and maintained by their users.

Please make bug reports and suggestions as [GitHub Issues][issues].
Pull requests are especially appreciated.

But first, please check that your issue has not already been reported by
someone else, and that it is not already fixed by [master][github] in
preparation for the next release (see Installation section above for how
to temporarily install master with [LuaRocks][]).

There is no strict coding style, but please bear in mind the following
points when proposing changes:

0. Follow existing code. There are a lot of useful patterns and avoided
   traps there.

1. 3-character indentation using SPACES in Lua sources: It makes rogue
   TABs easier to see, and lines up nicely with 'if' and 'end' keywords.

2. Simple strings are easiest to type using single-quote delimiters,
   saving double-quotes for where a string contains apostrophes.

3. Save horizontal space by only using SPACEs where the parser requires
   them.

4. Use vertical space to separate out compound statements to help the
   coverage reports discover untested lines.

[issues]: https://github.com/lua-stdlib/functional/issues
