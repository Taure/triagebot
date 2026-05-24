# syntax=docker/dockerfile:1.7
#
# Multi-stage Dockerfile for triagebot. Mirrors the Taure/asobi_site
# pattern; runtime image only carries the dynamic libs ERTS links
# against (the prod release brings its own ERTS).
#
# Clever Cloud detects this file on a Docker-type app and runs the
# resulting container directly.

# --- build stage ---------------------------------------------------
FROM erlang:28 AS builder

WORKDIR /app

# `git` is needed because the gakudan family deps are pinned via
# git tags, not Hex.
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# Fetch + compile deps separately so source-only changes don't bust
# the dep layer.
COPY rebar.config rebar.lock ./
RUN rebar3 compile --deps_only

COPY config ./config
COPY src ./src

RUN rebar3 as prod release

# --- runtime stage -------------------------------------------------
FROM debian:trixie-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libssl3 libncurses6 libstdc++6 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/triagebot ./

# Nova HTTP listener + gakudan_metrics /metrics
EXPOSE 8080
EXPOSE 9568

CMD ["bin/triagebot", "foreground"]
