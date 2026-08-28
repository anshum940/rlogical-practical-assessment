ARG ALPINE_VERSION=3.24
ARG NODE_BUILDER_IMAGE=node:24-alpine3.24@sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf
ARG ALPINE_RUNTIME_IMAGE=alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

FROM ${NODE_BUILDER_IMAGE} AS build

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev

COPY . .

FROM ${ALPINE_RUNTIME_IMAGE}

WORKDIR /app

RUN apk add --no-cache libstdc++ \
    && addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && chown node:node /app

COPY --from=build /usr/local/bin/node /usr/local/bin/node
COPY --from=build --chown=node:node /app/ /app/

ENV NODE_ENV=production

EXPOSE 3000

USER node

ENTRYPOINT ["node", "server.js"]
