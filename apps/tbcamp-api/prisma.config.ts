// Prisma 7 は .env を自動で読まないため、CLI 用に明示的に読み込む
import 'dotenv/config';
import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'tsx prisma/seed.ts',
  },
  datasource: {
    // env('DATABASE_URL') は未設定だと設定の読み込み時点で例外になり、
    // DB に接続しない prisma generate（Docker のビルド中など）まで失敗するため、process.env で読む
    url: process.env.DATABASE_URL,
  },
});
