# renovate: datasource=npm depName=renovate versioning=npm
ARG RENOVATE_VERSION=32.151.2

# Base image
#============
FROM alekitto/buildpack:1.0.4 AS base

LABEL name="renovate"
LABEL org.opencontainers.image.source="https://github.com/renovatebot/renovate" \
  org.opencontainers.image.url="https://renovatebot.com" \
  org.opencontainers.image.licenses="AGPL-3.0-only"

# renovate: datasource=node
RUN install-tool node v14.20.0

# renovate: datasource=npm versioning=npm
RUN install-tool yarn 1.22.19

# renovate: datasource=github-releases lookupName=containerbase/python-prebuild
RUN install-tool python 3.10.6

WORKDIR /usr/src/app

# Build image
#============
FROM base as tsbuild

COPY . .

RUN apt-get update -qq && \
    apt-get install -y make build-essential g++

RUN set -ex; \
  yarn install; \
  yarn build; \
  chmod +x dist/*.js;

# hardcode node version to renovate
RUN set -ex; \
  NODE_VERSION=$(node -v | cut -c2-); \
  sed -i "1 s:.*:#\!\/opt\/buildpack\/tools\/node\/${NODE_VERSION}\/bin\/node:" "dist/renovate.js"; \
  sed -i "1 s:.*:#\!\/opt\/buildpack\/tools\/node\/${NODE_VERSION}\/bin\/node:" "dist/config-validator.js";

ARG RENOVATE_VERSION
RUN set -ex; \
  yarn version --new-version ${RENOVATE_VERSION}; \
  yarn add -E  renovate@${RENOVATE_VERSION} --production;  \
  node -e "new require('re2')('.*').exec('test')";


# Final image
#============
FROM base as final

# renovate: datasource=docker versioning=docker
RUN install-tool docker 20.10.17

# renovate: datasource=adoptium-java
RUN install-tool java 11.0.16+8

# renovate: datasource=gradle-version versioning=gradle
RUN install-tool gradle 7.5.1

# renovate: datasource=github-releases lookupName=containerbase/erlang-prebuild versioning=docker
RUN install-tool erlang 24.3.4.2

# renovate: datasource=docker versioning=docker
RUN install-tool elixir 1.13.4

# renovate: datasource=github-releases lookupName=containerbase/php-prebuild
RUN install-tool php 7.4.30

# renovate: datasource=github-releases lookupName=composer/composer
RUN install-tool composer 2.3.10

# renovate: datasource=golang-version
RUN install-tool golang 1.19.0

# renovate: datasource=pypi
RUN install-pip pipenv 2022.8.5

# renovate: datasource=github-releases lookupName=python-poetry/poetry
RUN install-tool poetry 1.1.14

# renovate: datasource=pypi
RUN install-pip hashin 0.17.0

# renovate: datasource=pypi
RUN install-pip pip-tools 6.8.0

# renovate: datasource=docker versioning=docker
RUN install-tool rust 1.62.1

# renovate: datasource=github-releases lookupName=containerbase/ruby-prebuild
RUN install-tool ruby 3.1.2

# renovate: datasource=rubygems versioning=ruby
RUN install-gem bundler 2.3.19

# renovate: datasource=rubygems versioning=ruby
RUN install-gem cocoapods 1.11.3

# renovate: datasource=docker lookupName=mcr.microsoft.com/dotnet/sdk
RUN install-tool dotnet 6.0.302

# renovate: datasource=npm versioning=npm
RUN install-tool pnpm 6.33.1

# renovate: datasource=npm versioning=npm
RUN install-npm lerna 4.0.0

# renovate: datasource=github-releases lookupName=helm/helm
RUN install-tool helm v3.9.2

# renovate: datasource=github-releases lookupName=jsonnet-bundler/jsonnet-bundler
RUN install-tool jb v0.5.1

COPY --from=tsbuild /usr/src/app/package.json package.json
COPY --from=tsbuild /usr/src/app/dist dist
COPY --from=tsbuild /usr/src/app/node_modules node_modules

# exec helper
COPY bin/ /usr/local/bin/
RUN ln -sf /usr/src/app/dist/renovate.js /usr/local/bin/renovate;
RUN ln -sf /usr/src/app/dist/config-validator.js /usr/local/bin/renovate-config-validator;
CMD ["renovate"]


RUN set -ex; \
  renovate --version; \
  renovate-config-validator; \
  node -e "new require('re2')('.*').exec('test')";

ARG RENOVATE_VERSION
LABEL org.opencontainers.image.version="${RENOVATE_VERSION}"

# Numeric user ID for the ubuntu user. Used to indicate a non-root user to OpenShift
USER 1000
