# tech-boost-camp
Tech × Trek. A training camp to boost your skills, rep by rep, day by day.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## ローカルでの起動

前提: [mise](https://mise.jdx.dev/) で Node と pnpm を入れ（`mise install`）、Docker が使えること。

```bash
# 1. PostgreSQL を起動する（ホストの 127.0.0.1:5433 で待ち受ける）
docker compose up -d postgres

# 2. 依存をインストールし、環境変数ファイルを用意する
pnpm install
cp apps/tbcamp-api/.env.example apps/tbcamp-api/.env
cp apps/tbcamp-web/.env.example apps/tbcamp-web/.env

# 3. マイグレーションと seed を流す
pnpm --filter tbcamp-api exec prisma migrate dev
pnpm --filter tbcamp-api exec prisma db seed

# 4. api と web をそれぞれ別のターミナルで起動する
pnpm dev:api   # http://localhost:4000
pnpm dev:web   # http://localhost:3000
```
