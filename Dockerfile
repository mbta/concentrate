# get from https://hub.docker.com/r/hexpm/elixir/tags
FROM hexpm/elixir:1.12.0-erlang-23.3.4.1-alpine-3.13.3 AS builder

WORKDIR /root

# Install Hex+Rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# Install git
RUN apk --update add git make

ENV MIX_ENV=prod

ADD mix.* /root/
ADD config /root/config

RUN mix do deps.get --only prod, deps.compile

ADD lib /root/lib
ADD src /root/src

RUN mix do compile, release

# Second stage: copies the files from the builder stage
FROM alpine:3.13.3

RUN apk add --update libssl1.1 ncurses-libs bash dumb-init \
    && rm -rf /var/cache/apk

# Set environment
ENV MIX_ENV=prod TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

WORKDIR /root/

COPY --from=builder /root/_build/prod/rel /root/rel

# Ensure SSL support is enabled
RUN /root/rel/concentrate/bin/concentrate eval ":crypto.supports()"

HEALTHCHECK CMD ["/root/rel/concentrate/bin/concentrate", "rpc", "Concentrate.Health.healthy?()"]
CMD ["/usr/bin/dumb-init", "/root/rel/concentrate/bin/concentrate", "start"]
