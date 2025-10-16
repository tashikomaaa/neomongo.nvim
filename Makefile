# Developer helpers to keep linting and formatting consistent with CI.
.PHONY: lint format format-check

lint:
	luacheck lua

format:
	stylua lua

format-check:
	stylua --check lua
