// ロードバランサのヘルスチェック。プロセスが応答できれば 200 を返す
export function GET() {
  return Response.json({ status: 'ok' });
}
