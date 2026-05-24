.PHONY: deps test fmt lint

deps:
	@if [ ! -d .deps/mini.nvim ]; then \
		mkdir -p .deps; \
		git clone --quiet --filter=blob:none https://github.com/echasnovski/mini.nvim.git .deps/mini.nvim; \
	fi

test: deps
	nvim --clean --headless -u tests/minimal-init.lua -c "lua MiniTest.run()"

fmt:
	stylua .

lint:
	luacheck lua plugin tests
