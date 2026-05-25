.PHONY: deps test test-verbose fmt lint

deps:
	@if [ ! -d .deps/mini.nvim ]; then \
		mkdir -p .deps; \
		git clone --quiet --filter=blob:none https://github.com/echasnovski/mini.nvim.git .deps/mini.nvim; \
	fi

test: deps
	nvim --clean --headless -u tests/minimal-init.lua -c "lua MiniTest.run()"

test-verbose: deps
	nvim --clean --headless -u tests/minimal-init.lua -c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = 2 }) } })"

fmt:
	stylua .

lint:
	luacheck lua plugin tests
