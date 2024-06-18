ARG ELIXIR_VERSION=1.17.1
ARG ERLANG_VERSION=27.0
ARG ALPINE_VERSION=3.20.0
FROM hexpm/elixir:$ELIXIR_VERSION-erlang-$ERLANG_VERSION-alpine-$ALPINE_VERSION AS builder

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
FROM alpine:$ALPINE_VERSION

RUN apk add --update libcrypto3 ncurses-libs bash dumb-init libstdc++ \
    && apk upgrade \
    && rm -rf /var/cache/apk

# Set environment
ENV MIX_ENV=prod TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

WORKDIR /root/

COPY --from=builder /root/_build/prod/rel /root/rel

# Ensure SSL support is enabled
RUN /root/rel/concentrate/bin/concentrate eval ":crypto.supports()"

HEALTHCHECK CMD ["/root/rel/concentrate/bin/concentrate", "rpc", "Concentrate.Health.healthy?()"]
CMD ["/usr/bin/dumb-init", "/root/rel/concentrate/bin/concentrate", "start"]
