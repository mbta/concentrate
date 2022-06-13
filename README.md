# Concentrate

[![Elixir CI](https://github.com/mbta/concentrate/actions/workflows/elixir.yml/badge.svg)](https://github.com/mbta/concentrate/actions/workflows/elixir.yml)

Concentrate combines realtime transit information from multiple sources into
single output files.

## Configuration

Concentrate can either be configured via `config/config.exs` or a JSON environment variable as `CONCENTRATE_JSON`: more details are available in [configuration.md](guides/configuration.md).

## Architecture

See [architecture.md](guides/architecture.md) for the overall architecture of the system.

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
