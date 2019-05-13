# Concentrate

[![Build Status](https://semaphoreci.com/api/v1/mbta/concentrate/branches/master/badge.svg)](https://semaphoreci.com/mbta/concentrate)
[![Code Coverage](https://codecov.io/gh/mbta/concentrate/branch/master/graph/badge.svg)](https://codecov.io/gh/mbta/concentrate)

Concentrate combines realtime transit information from multiple sources into
single output files.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the overall architecture of the system.

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

## Docker

Concentrate comes with a Dockerfile, allowing you to build an image that can
be run anywhere Docker works. It's a [multi-stage](https://docs.docker.com/engine/userguide/eng-image/multistage-build/) build, so it requires at least Docker 17.05.

```
# build
docker build -t concentrate:latest .

# run
docker run concentrate:latest
```

It can be configured by passing a JSON configuration file as
`CONCENTRATE_JSON`. An example JSON configuration can be seen in [test/concentrate_test.exs](https://github.com/mbta/concentrate/blob/master/test/concentrate_test.exs#L17-L57).

Test
