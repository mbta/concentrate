#!/bin/bash
set -e -x -u

mkdir -p _build/dev
find $SEMAPHORE_CACHE_DIR -name "dialyxir_*_deps-dev.plt*" | xargs -I{} cp '{}' _build/dev
export ERL_CRASH_DUMP=/dev/null
mix dialyzer --plt
cp _build/dev/*_deps-dev.plt* $SEMAPHORE_CACHE_DIR
mix dialyzer --halt-exit-status
