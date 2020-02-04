FROM erlang:21.1-alpine AS builder

# Install Elixir

# elixir expects utf8.
ENV ELIXIR_VERSION="v1.8.2" \
    LANG=C.UTF-8

RUN set -xe \
    && ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/${ELIXIR_VERSION}.tar.gz" \
    && ELIXIR_DOWNLOAD_SHA256="cf9bf0b2d92bc4671431e3fe1d1b0a0e5125f1a942cc4fdf7914b74f04efb835" \
    && buildDeps=' \
        ca-certificates \
        curl \
        make \
    ' \
    && apk add --no-cache --virtual .build-deps $buildDeps \
    && curl -fSL -o elixir-src.tar.gz $ELIXIR_DOWNLOAD_URL \
    && echo "$ELIXIR_DOWNLOAD_SHA256  elixir-src.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/local/src/elixir \
    && tar -xzC /usr/local/src/elixir --strip-components=1 -f elixir-src.tar.gz \
    && rm elixir-src.tar.gz \
    && cd /usr/local/src/elixir \
    && make install clean \
    && apk del .build-deps

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

# Second stage: uses the built .tgz to get the files over
FROM alpine:3.8

RUN apk add --update libssl1.0 ncurses-libs bash dumb-init \
    && rm -rf /var/cache/apk

# Set environment
ENV MIX_ENV=prod TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

WORKDIR /root/

COPY --from=builder /root/_build/prod/rel /root/rel

# Ensure SSL support is enabled
RUN /root/rel/concentrate/bin/concentrate eval ":crypto.supports()"

HEALTHCHECK CMD ["/root/rel/concentrate/bin/concentrate", "rpc", "--mfa", "Concentrate.Health.healthy?/0"]
CMD ["/usr/bin/dumb-init", "/root/rel/concentrate/bin/concentrate", "foreground"]
