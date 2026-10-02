std = "lua51"
max_line_length = 100
exclude_files = { "src/vendor/**" }

files["main.lua"] = { globals = { "love" }, read_globals = { "arg" } }
files["conf.lua"] = { globals = { "love" }, read_globals = { "arg" } }
files["src/ui/**"] = { read_globals = { "love" } }
files["src/platform/**"] = { read_globals = { "love", "arg" } }
files["src/app/desktop.lua"] = { read_globals = { "love" } }
files["src/app/smoke_test.lua"] = { read_globals = { "love" } }
