import type { NextConfig } from 'next';

// ブラウザは常に同一オリジンの /api を叩く。
// ローカルでは Next.js がこの rewrite で backend に転送する。
// 本番ではロードバランサが /api を backend に振るため、この rewrite は通らない。
// どちらの環境でもフロントのコードは変わらない。
const nextConfig: NextConfig = {
  // コンテナ用に、実行に必要なファイルだけを .next/standalone に出力する
  output: 'standalone',
  async rewrites() {
    const target = process.env.API_PROXY_TARGET ?? 'http://localhost:4000';
    return [{ source: '/api/:path*', destination: `${target}/api/:path*` }];
  },
};

export default nextConfig;
