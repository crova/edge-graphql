FROM elixir:1.10-alpine AS build

# install build dependencies
RUN apk add --no-cache build-base npm

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV SECRET_KEY_BASE=nokey

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod
RUN MIX_ENV=prod mix deps.compile

# build assets
COPY priv priv

# compile and build release
COPY lib lib
RUN MIX_ENV=prod mix release

# prepare release image
FROM alpine:3.9 AS app
RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/edge_graphql ./

ADD entrypoint.sh ./

ENV HOME=/app
ENV MIX_ENV=prod
ENV SECRET_KEY_BASE=nokey
ENV PORT=4000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["bin/edge_graphql", "start"]
