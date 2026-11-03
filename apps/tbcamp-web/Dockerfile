# ビルドコンテキストはリポジトリ直下（モノレポのため）。
#   docker build -f apps/tbcamp-web/Dockerfile .

FROM node:24-slim AS base
RUN corepack enable

# 依存のインストール。package.json だけを先にコピーしてレイヤーキャッシュを効かせる
FROM base AS deps
WORKDIR /repo
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/tbcamp-web/package.json apps/tbcamp-web/
COPY packages/tbcamp-config/package.json packages/tbcamp-config/
COPY packages/tbcamp-core/package.json packages/tbcamp-core/
RUN pnpm install --frozen-lockfile --filter tbcamp-web...

FROM deps AS build
COPY packages packages
COPY apps/tbcamp-web apps/tbcamp-web
# rewrites の転送先は next build の時点で確定し、実行時の環境変数では変わらない。
# そのためビルド引数で受け取る。未指定なら next.config.ts の既定値になる
ARG API_PROXY_TARGET
RUN pnpm --filter tbcamp-web build

FROM base AS runtime
WORKDIR /app
ENV NODE_ENV=production \
  PORT=3000 \
  HOSTNAME=0.0.0.0
# standalone の出力はモノレポの構成を保ったまま apps/tbcamp-web/server.js に置かれる
COPY --from=build --chown=node:node /repo/apps/tbcamp-web/.next/standalone ./
COPY --from=build --chown=node:node /repo/apps/tbcamp-web/.next/static ./apps/tbcamp-web/.next/static
USER node
EXPOSE 3000
CMD ["node", "apps/tbcamp-web/server.js"]
