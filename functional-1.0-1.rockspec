package = "functional"
version = "1.0-1"

description = {
  summary = "Functional Programming with Lua",
  detailed = [[
    An immutable tuple object, and many higher-order functions to help
    program in a functional style using tuples and Lua tables.
  ]],
  homepage = "http://lua-stdlib.github.io/functional",
  license = "MIT/X11",
}

source = {
  url = "git://github.com/lua-stdlib/functional.git",
}

dependencies = {
  "lua >= 5.1, < 5.4",
}

build = {
  type = "builtin",
  modules = {
    functional = "lib/functional/init.lua",
    ["functional._base"] = "lib/functional/_base.lua",
    ["functional.operator"] = "lib/functional/operator.lua",
    ["functional.tuple"] = "lib/functional/tuple.lua",
  },
}
