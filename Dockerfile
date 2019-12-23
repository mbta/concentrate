FROM elixir:1.10.1-alpine AS builder

WORKDIR /root

# Install Hex+Rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# Install git
RUN apk --update add git make

ENV MIX_ENV=prod

ADD mix.* /root/

RUN elixir --erl "-smp enable" /usr/local/bin/mix do deps.get --only prod, deps.compile

ADD lib /root/lib
ADD src /root/src
ADD config /root/config
ADD rel /root/rel

RUN elixir --erl "-smp enable" /usr/local/bin/mix do compile, distillery.release --verbose

# Second stage: copies the files from the builder stage
FROM alpine:3.10

RUN apk add --update libssl1.1 ncurses-libs bash dumb-init \
    && rm -rf /var/cache/apk

# Set environment
ENV MIX_ENV=prod TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

WORKDIR /root/

COPY --from=builder /root/_build/prod/rel /root/rel

# Ensure SSL support is enabled
RUN /root/rel/concentrate/bin/concentrate eval ":crypto.supports()"

HEALTHCHECK CMD ["/root/rel/concentrate/bin/concentrate", "rpc", "--mfa", "Concentrate.Health.healthy?/0"]
CMD ["/usr/bin/dumb-init", "/root/rel/concentrate/bin/concentrate", "foreground"]
