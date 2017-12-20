# Concentrate

[![Build Status](https://semaphoreci.com/api/v1/mbta/concentrate/branches/master/badge.svg)](https://semaphoreci.com/mbta/concentrate)

Concentrate combines realtime transit information from multiple sources into
single output files.

## Development Setup

```
# after installing asdf from https://github.com/asdf-vm/asdf..
asdf install

# get Elixir dependencies
mix deps.get

# add pre-commit hook to verify formatting/tests/types
ln -s ../../hooks/pre-commit .git/hooks/pre-commit

# make sure everything passes! (slowest to fastest)
mix format --check-formatted
mix credo
mix test
mix dialyzer
```
