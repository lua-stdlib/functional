# Functional API for Lua 5.1, 5.2, 5.3 & 5.4
# Copyright (C) 2002-2022 std.functional authors

LDOC	= ldoc
LUA	= lua
MKDIR	= mkdir -p
SED	= sed
SPECL	= specl

VERSION	= 1.0

luadir	= lib/std/functional
SOURCES =				\
	$(luadir)/_base.lua		\
	$(luadir)/init.lua		\
	$(luadir)/operator.lua		\
	$(luadir)/tuple.lua		\
	$(luadir)/version.lua		\
	$(NOTHING_ELSE)


all: $(luadir)/version.lua


$(luadir)/version.lua: Makefile
	    echo 'return "Functional Programming Libraries / $(VERSION)"' > '$@'

doc: build-aux/config.ld $(SOURCES)
	$(LDOC) -c build-aux/config.ld .

build-aux/config.ld: build-aux/config.ld.in
	$(SED) -e "s,@PACKAGE_VERSION@,$(VERSION)," '$<' > '$@'


CHECK_ENV = LUA=$(LUA)

check:
	LUA=$(LUA) $(SPECL) $(SPECL_OPTS) spec/*_spec.yaml
