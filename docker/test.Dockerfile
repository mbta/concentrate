FROM hexpm/elixir:1.10.4-erlang-23.3.4.14-alpine-3.16.0 AS builder
WORKDIR /root
# Install Hex+Rebar
RUN mix local.hex --force && \
    mix local.rebar --force
# Install git
RUN apk --update add git make
ENV MIX_ENV=test
ADD . .
RUN mix do deps.get, deps.compile
RUN mix do compile
