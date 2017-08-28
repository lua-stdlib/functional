local _MODREV, _SPECREV = 'git', '-1'

package = 'functional'
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
   'lua >= 5.1, < 5.4',
   'ldoc',
}

build = {
   type = 'builtin',
   modules = {
      ['functional'] = 'lib/functional/init.lua',
      ['functional._base'] = 'lib/functional/_base.lua',
      ['functional.operator'] = 'lib/functional/operator.lua',
      ['functional.tuple'] = 'lib/functional/tuple.lua',
      ['functional.version'] = 'lib/functional/version.lua',
   },
}
