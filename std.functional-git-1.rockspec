local _MODREV, _SPECREV = 'git', '-1'

package = 'std.functional'
version = _MODREV .. _SPECREV

description = {
   summary = 'Functional Programming with Lua',
   detailed = [[
      An immutable tuple object, and many higher-order functions to help
      program in a functional style using tuples and Lua tables.
   ]],
   homepage = 'http://lua-stdlib.github.io/functional',
   license = 'MIT/X11',
}

source = {
   url = 'git://github.com/lua-stdlib/functional.git',
   --url = 'http://github.com/lua-stdlib/functional/archive/v' .. _MODREV .. '.zip',
   --dir = 'functional-' .. _MODREV,
}

dependencies = {
   'ldoc',
   'lua >= 5.1, < 5.4',
   'std.normalize >= 1.0.3',
}

build = {
   type = 'builtin',
   modules = {
      ['std.functional'] = 'lib/std/functional/init.lua',
      ['std.functional._base'] = 'lib/std/functional/_base.lua',
      ['std.functional.operator'] = 'lib/std/functional/operator.lua',
      ['std.functional.tuple'] = 'lib/std/functional/tuple.lua',
      ['std.functional.version'] = 'lib/std/functional/version.lua',
   },
}
