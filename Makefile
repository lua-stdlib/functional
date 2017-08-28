LDOC	= ldoc
LUA	= lua
MKDIR	= mkdir -p
SED	= sed
SPECL	= specl

VERSION	= git

luadir	= lib/functional
SOURCES =				\
	$(luadir)/_base.lua		\
	$(luadir)/init.lua		\
	$(luadir)/operator.lua		\
	$(luadir)/tuple.lua		\
	$(luadir)/version.lua		\
	$(NOTHING_ELSE)


all: $(luadir)/version.lua doc


$(luadir)/version.lua: .FORCE
	@echo 'return "Functional Programming Libraries / $(VERSION)"' > '$@T';	\
	if cmp -s '$@' '$@T'; then						\
	    rm -f '$@T';							\
	else									\
	    echo 'echo "Functional Programming Libraries / $(VERSION)" > $@';	\
	    mv '$@T' '$@';							\
	fi

doc: build-aux/config.ld $(SOURCES)
	$(LDOC) -c build-aux/config.ld .

build-aux/config.ld: build-aux/config.ld.in
	$(SED) -e "s,@PACKAGE_VERSION@,$(VERSION)," '$<' > '$@'


CHECK_ENV = LUA=$(LUA)

check:
	LUA=$(LUA) $(SPECL) $(SPECL_OPTS) specs/*_spec.yaml


.FORCE:
