# syntax=docker/dockerfile:1.7

ARG NODE_IMAGE=node:26.5.0-bookworm-slim
ARG PNPM_VERSION=11.15.1

FROM ${NODE_IMAGE} AS pnpm-base
ARG PNPM_VERSION
RUN npm install --global "pnpm@${PNPM_VERSION}"
WORKDIR /app

FROM pnpm-base AS development-dependencies
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
RUN --mount=type=cache,id=kara-website-pnpm,target=/pnpm/store \
	pnpm install --frozen-lockfile --store-dir=/pnpm/store

FROM development-dependencies AS build
COPY . .
RUN pnpm build

FROM pnpm-base AS production-dependencies
ENV NODE_ENV=production
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
RUN --mount=type=cache,id=kara-website-pnpm,target=/pnpm/store \
	pnpm install --prod --frozen-lockfile --ignore-scripts --store-dir=/pnpm/store

FROM ${NODE_IMAGE} AS runtime
ENV NODE_ENV=production \
	HOST=0.0.0.0 \
	PORT=3000 \
	SHUTDOWN_TIMEOUT=10
WORKDIR /app

COPY --from=production-dependencies --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/build ./build
COPY --chown=node:node package.json ./package.json

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD node -e "fetch('http://127.0.0.1:3000/v1/manifest.json').then((response) => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "build"]
