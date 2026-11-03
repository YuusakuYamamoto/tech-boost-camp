// backend の死活は見ない。backend が落ちたときに frontend までロードバランサから外れると、
// エラー画面すら出せなくなるため
export function GET() {
  return Response.json({ status: 'ready' });
}
