# ビルドコンテキストはリポジトリ直下（モノレポのため）。
#   docker build -f apps/tbcamp-api/Dockerfile .

FROM node:24-slim AS base
# Prisma のクエリエンジンは libssl を必要とするが、slim イメージには入っていない
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl \
  && rm -rf /var/lib/apt/lists/*
RUN corepack enable

# 依存のインストール。package.json だけを先にコピーしてレイヤーキャッシュを効かせる
FROM base AS deps
WORKDIR /repo
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/tbcamp-api/package.json apps/tbcamp-api/
COPY packages/tbcamp-config/package.json packages/tbcamp-config/
COPY packages/tbcamp-core/package.json packages/tbcamp-core/
RUN pnpm install --frozen-lockfile --filter tbcamp-api...

# ビルドと、実行に必要なものだけを /out に切り出す
FROM deps AS build
COPY packages packages
COPY apps/tbcamp-api apps/tbcamp-api
RUN pnpm --filter tbcamp-api exec prisma generate \
  && pnpm --filter tbcamp-api build
# 本番依存にワークスペースのパッケージは無い（tbcamp-core は型だけ）ため、
# inject を使わない --legacy の deploy で足りる
RUN pnpm --filter tbcamp-api deploy --prod --legacy /out
# deploy は本番依存を入れ直すため、Prisma Client を /out 側で生成し直す
RUN cd /out && /repo/apps/tbcamp-api/node_modules/.bin/prisma generate

FROM base AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build --chown=node:node /out ./
USER node
EXPOSE 4000
CMD ["node", "dist/main.js"]
