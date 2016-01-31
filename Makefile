LDOC	= ldoc
LUA	= lua
MKDIR	= mkdir -p
SED	= sed
SPECL	= specl

luadir	= lib/functional
SOURCES = $(luadir)/_base.lua $(luadir)/init.lua $(luadir)/operator.lua $(luadir)/tuple.lua


all: doc

doc: doc/config.ld $(SOURCES)
	$(LDOC) -c doc/config.ld .

doc/config.ld: doc/config.ld.in
	version=`LUA_PATH=$$(pwd)'/lib/?.lua;;' $(LUA) -e 'io.stdout:write(require"functional._base"._VERSION)'`; \
	$(SED) -e "s,@PACKAGE_VERSION@,$$version," '$<' > '$@'


CHECK_ENV = LUA=$(LUA)

check:
	LUA=$(LUA) $(SPECL) $(SPECL_OPTS) specs/*_spec.yaml
