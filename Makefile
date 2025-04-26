LUA_VERSION_REQUIRED=5.1

# Commands
LUA=$(shell command -v lua 2> /dev/null)
LUAROCKS=$(shell command -v luarocks 2> /dev/null)
BUSTED=$(shell command -v busted 2> /dev/null)

# Rules
.PHONY: all check test install-busted

all: check test

check:
ifndef LUA
	$(error "Lua is not installed. Please install Lua $(LUA_VERSION_REQUIRED).")
endif
ifndef LUAROCKS
	$(error "Luarocks is not installed. Please install luarocks.")
endif
ifndef BUSTED
	@echo "Busted is not installed. Installing busted using luarocks..."
	@luarocks install busted
endif
	@echo "All dependencies are present."

test:
	@echo "Running tests..."
	busted --lpath=./lua/?.lua --lpath=./lua/?/init.lua tests/

install-busted:
	@echo "Installing busted via luarocks..."
	luarocks install busted
