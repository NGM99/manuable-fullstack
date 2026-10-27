FROM node:24.22.1-bookworm-slim AS node_runtime
FROM ruby:3.4.12-slim-bookworm AS base
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y build-essential libpq-dev libyaml-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
FROM base AS development
ENV BUNDLE_FROZEN=true
COPY backend/Gemfile backend/Gemfile.lock ./
RUN bundle install
COPY backend/ ./
EXPOSE 3000
ENTRYPOINT ["sh", "/app/bin/docker-entrypoint"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]

# Both suites run in one container, without a Docker socket or host runtimes.
FROM development AS tests
COPY --from=node_runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node_runtime /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
WORKDIR /frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
COPY bin/test-suite /usr/local/bin/test-suite
WORKDIR /app
ENTRYPOINT ["sh", "/usr/local/bin/test-suite"]
CMD []
