local _MODREV, _SPECREV = 'dev', '-1'

package = 'std.functional'
version = _MODREV .. _SPECREV

rockspec_format = '3.0'

description = {
   summary = 'Functional Programming with Lua',
   detailed = [[
      An immutable tuple object, and many higher-order functions to help
      program in a functional style using tuples and Lua tables.
   ]],
   homepage = 'https://lua-stdlib.github.io/functional',
   license = 'MIT/X11',
}

dependencies = {
   'lua >= 5.1, < 5.6',
   'std.normalize >= 4',
}

source = {
   url = 'https://github.com/lua-stdlib/functional/archive/v' .. _MODREV .. '.zip',
   dir = 'functional-' .. _MODREV,
}

build_dependencies = {
   'luarocks-build-luke >= 0.2',
}

build = {
   type = 'luke',

   modules = {
      {['std.functional']          = 'lib/std/functional/init.lua'},
      {['std.functional._base']    = 'lib/std/functional/_base.lua'},
      {['std.functional.operator'] = 'lib/std/functional/operator.lua'},
      {['std.functional.tuple']    = 'lib/std/functional/tuple.lua'},
      {['std.functional.version']  = 'lib/std/functional/version.lua.in'},
   },

   -- A release commits its LDocs to install.
   copy_directories = {'doc'},
}

test_dependencies = {
   'ansicolors',
   'luacov',
   'specl >= 17',
}

test = {
   type = 'command',
   command = 'specl -vfreport --coverage spec/*_spec.yaml',
}

if _MODREV == 'dev' then
   -- luarocks.org's ldoc fails on Lua 5.5; gvvaughan's works.
   build_dependencies[#build_dependencies + 1] = 'gvvaughan/ldoc'

   -- Stamp a development build with who made it, and from which commit.
   build.version = '$USER/$gitref'

   build.copy_directories = nil

   source = {
      url = 'git+https://github.com/lua-stdlib/functional.git',
   }
end
