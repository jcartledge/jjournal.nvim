#!/bin/bash
# tests/scripts/run.sh

# 1. Clean up stale test artifacts at the project root level
rm -f luacov.stats.out luacov.report.out

# 2. Inject the local LuaRocks environment sandbox paths
eval "$(luarocks path --tree=.rocks)"

# 3. Prepend our local plugin directory onto the Lua path matrix
export LUA_PATH="./lua/?.lua;./lua/?/init.lua;$LUA_PATH"

# 4. Run the suite inside the Neovim headless interpreter mode
nvim -l tests/scripts/run.lua tests/
TEST_EXIT_CODE=$?

# 5. Generate the standardized LCOV report data natively into luacov.report.out
.rocks/bin/luacov -r lcov

# 6. Parse and print the global coverage summary directly from luacov.report.out
echo ""
if [ -s luacov.report.out ]; then
    echo "=================================="
    echo "📊 Global Test Coverage Summary:"
    awk -F':' '
      $1 == "LF" {lf+=$2} 
      $1 == "LH" {lh+=$2} 
      END {
        if (lf>0) 
          printf "   Total Line Coverage: %.2f%% (%d/%d lines)\n", (lh/lf)*100, lh, lf; 
        else 
          print "   No executable lines found in report mapping."
      }
    ' luacov.report.out
    echo "=================================="
else
    echo "⚠️  Error: luacov.report.out is empty or missing."
fi

exit $TEST_EXIT_CODE
