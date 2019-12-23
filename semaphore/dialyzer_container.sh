#!/bin/bash
set -eu

# copy any pre-built PLTs to the right directory
find _build/dialyxir -name "dialyxir_*.plt" | xargs -I{} cp '{}' _build/test

export ERL_CRASH_DUMP=/dev/null
mix dialyzer --plt

# copy built PLTs back
cp _build/test/dialyxir*.plt _build/dialyxir

mix dialyzer --halt-exit-status
