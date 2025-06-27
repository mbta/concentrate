# Concentrate

[![Elixir CI](https://github.com/mbta/concentrate/actions/workflows/elixir.yml/badge.svg)](https://github.com/mbta/concentrate/actions/workflows/elixir.yml)

Concentrate combines realtime transit information from multiple sources into
single output files.

## Configuration

Concentrate can either be configured via `config/config.exs` or a JSON environment variable as `CONCENTRATE_JSON`: more details are available in [configuration.md](guides/configuration.md).

An example run commands bash script for configuring Concentrate is available in `.envrc.example`. Note that you must run apply this configuration in a bash shell by using `source` instead of via `direnv` or a
similar tool, since it runs bash commands.

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
mix dialyzer
```

See [the section on tests below](#tests) for information on running unit tests, which requires having a local MQTT broker running.

If you run into issues compiling `snabbkaffe`:

``` shell
rm -fr deps/quicer
mix deps.get
mix deps.compile
```

### Tests
[tests]: #tests

To run the tests, first install and setup Colima, Docker, and docker-compose:

```shell
brew install docker docker-compose colima
colima start
mkdir -p ${DOCKER_CONFIG:-"~/.docker"}/cli-plugins
ln -sfn /opt/homebrew/opt/docker-compose/bin/docker-compose ${DOCKER_CONFIG:-"~/.docker"}/cli-plugins/docker-compose
```

Then, start the Compose configuration in a separate window or tab and run the tests: 
1. `docker compose up` 
1. `mix test`

## Docker

Concentrate comes with a Dockerfile, allowing you to build an image that can
be run anywhere Docker works. It's a [multi-stage](https://docs.docker.com/engine/userguide/eng-image/multistage-build/) build, so it requires at least Docker 17.05.

```
# build
docker build -t concentrate:latest .

# run
docker run concentrate:latest
```
