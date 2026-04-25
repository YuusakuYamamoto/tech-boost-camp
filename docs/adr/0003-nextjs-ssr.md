# ADR-0003: Next.js は SSR 前提で運用する

- **Status**: Proposed
- **Date**: 2026-04-25
- **Deciders**: Yusaku

## Context

フロントエンドは Next.js を採用済み。Next.js のレンダリング戦略には以下の選択肢がある：

- **SSR（Server-Side Rendering）**: アクセス時にサーバ側で HTML を生成
- **SSG（Static Site Generation）**: ビルド時に HTML を全生成
- **ISR（Incremental Static Regeneration）**: SSG の亜種、定期再生成

本アプリは認証付きで仲間内向け。ログイン後の画面で DB の動的データを表示する性質を持つ。

## Decision

Next.js は **SSR 前提**で運用する。デプロイ先は Container Instances（ADR-0001）とし、Node.js プロセスとして常時稼働させる。

## Alternatives Considered

### SSG / 静的エクスポート + Object Storage 配信

- **不採用理由**:
  - ログイン必須で DB の最新状態を即時反映する画面が中心であり、静的化のメリットが活きない
  - SPA 化すると初期表示まで JS 実行を待つ必要があり、ユーザ体験が劣化する
  - Next.js の App Router は SSR 前提の設計

### 別フレームワーク（Vite + React の SPA）への変更

- **不採用理由**:
  - 既に Next.js を採用しているため変更コストが見合わない
  - SPA + 別バックエンドの構成は CORS・API 認証フローが煩雑

## Consequences

### Positive

- ログイン後の画面で DB の最新データを含んだ HTML を即座に返せる
- App Router など Next.js の標準的な書き方が活かせる
- フロントとバックを同一ドメイン下で運用しやすい（ADR-0005 参照）

### Negative / Trade-off

- フロントも常時稼働の Container Instance が必要（Always Free 枠で吸収可能）
- Node.js プロセスのライフサイクル管理（メモリリーク監視等）が必要

### Neutral

- ブラウザからの API 呼び出しと Next.js サーバ側からの API 呼び出しの両方を考慮した設計が必要
