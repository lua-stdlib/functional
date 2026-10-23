local _MODREV, _SPECREV = '2', '-1'

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

build = {
   type = 'command',
   build_command = '$(LUA) build-aux/luke'
      .. ' package="' .. package .. '"'
      .. ' version="' .. _MODREV .. '"'
      .. ' PREFIX="$(PREFIX)"'
      .. ' LUA="$(LUA)"'
      ,
   install_command = '$(LUA) build-aux/luke install --quiet'
      .. ' INST_LUADIR="$(LUADIR)"'
      ,
   copy_directories = {'doc'},
}

test_dependencies = {
   'ansicolors',
   'luacov',
   'specl >= 16',
}

test = {
   type = 'command',
   command = 'specl -vfreport --coverage spec/*_spec.yaml',
}

if _MODREV == 'dev' then
   -- luarocks.org's ldoc fails on Lua 5.5; gvvaughan's works.
   build_dependencies = {'gvvaughan/ldoc'}

   build.copy_directories = nil

   source = {
      url = 'git+https://github.com/lua-stdlib/functional.git',
   }
else
   -- A release commits its LDocs, so don't build them again.
   build.build_command = build.build_command .. ' LDOC=true'
end
