import { PrismaClient } from '@prisma/client';

// ローカル開発用の問題データ。すべて自作であり、既存の試験問題からの転記は含まない
const questions = [
  {
    body: 'OCI でサブネットを作成する際、同一リージョン内のすべての可用性ドメインにまたがって配置できるサブネットの種類はどれか。',
    explanation:
      'リージョナルサブネットはリージョン内のすべての可用性ドメインにまたがるため、AD 障害時にも他の AD でインスタンスを起動できる。AD 固有サブネットは単一の AD に限定される。現在は特別な理由がなければリージョナルサブネットが推奨される。',
    choices: [
      { body: 'リージョナルサブネット', isCorrect: true },
      { body: '可用性ドメイン固有サブネット', isCorrect: false },
      { body: 'テナンシースコープのサブネット', isCorrect: false },
      { body: 'コンパートメント固有のサブネット', isCorrect: false },
    ],
  },
  {
    body: 'プライベートサブネット上のインスタンスから、インターネット上のパッケージリポジトリへ外向きの通信のみを許可したい。適切なゲートウェイはどれか。',
    explanation:
      'NAT ゲートウェイはプライベートサブネットからの外向き通信を許可し、インターネット側から始まる通信は通さない。インターネットゲートウェイは双方向の通信を許可するため、プライベートサブネットの要件には合わない。サービスゲートウェイは OCI のサービス向けで、インターネットには出られない。',
    choices: [
      { body: 'NAT ゲートウェイ', isCorrect: true },
      { body: 'インターネットゲートウェイ', isCorrect: false },
      { body: 'サービスゲートウェイ', isCorrect: false },
      { body: '動的ルーティングゲートウェイ', isCorrect: false },
    ],
  },
  {
    body: '同じサブネット内のインスタンスのうち、Web サーバーの役割を持つものにだけ HTTPS の受信を許可したい。サブネット単位ではなく VNIC 単位でセキュリティルールを適用できる仕組みはどれか。',
    explanation:
      'ネットワークセキュリティグループ（NSG）は、所属させた VNIC にだけルールを適用できる。セキュリティリストはサブネット内のすべての VNIC に一律で適用される。両方が適用される VNIC では、どちらか一方で許可されていれば通信は許可される。',
    choices: [
      { body: 'セキュリティリスト', isCorrect: false },
      { body: 'ネットワークセキュリティグループ', isCorrect: true },
      { body: 'ルート表', isCorrect: false },
      { body: 'DHCP オプション', isCorrect: false },
    ],
  },
  {
    body: '1 つの可用性ドメインの中で、ハードウェア障害や計画メンテナンスの影響が複数のインスタンスに同時に及ばないよう分散配置するための単位はどれか。',
    explanation:
      'フォールトドメインは可用性ドメイン内のハードウェアとインフラストラクチャのまとまりで、1 つの可用性ドメインに 3 つある。インスタンスを別々のフォールトドメインに配置すると、単一のハードウェア障害やメンテナンスの影響を受けにくくなる。コンパートメントはリソースを整理しアクセスを制御する論理的な単位で、物理的な配置とは関係しない。',
    choices: [
      { body: 'コンパートメント', isCorrect: false },
      { body: 'リージョン', isCorrect: false },
      { body: 'レルム', isCorrect: false },
      { body: 'フォールトドメイン', isCorrect: true },
    ],
  },
  {
    body: 'グループ NetworkAdmins に、コンパートメント Prod 内のネットワーク関連リソースの作成・変更・削除を許可したい。最も適切な IAM ポリシー文はどれか。',
    explanation:
      'ポリシー文は「Allow <主体> to <動詞> <リソースタイプ> in <場所>」の形で書く。動詞は inspect、read、use、manage の順に権限が広がり、リソースの作成と削除まで含むのは manage である。場所を tenancy にすると Prod 以外のコンパートメントにも権限が及ぶため、必要以上に広い。',
    choices: [
      {
        body: 'Allow group NetworkAdmins to use virtual-network-family in compartment Prod',
        isCorrect: false,
      },
      {
        body: 'Allow group NetworkAdmins to manage virtual-network-family in tenancy',
        isCorrect: false,
      },
      {
        body: 'Allow group NetworkAdmins to manage virtual-network-family in compartment Prod',
        isCorrect: true,
      },
      {
        body: 'Allow group NetworkAdmins to read virtual-network-family in compartment Prod',
        isCorrect: false,
      },
    ],
  },
];

const prisma = new PrismaClient();

async function main() {
  // ローカル専用のため、毎回全削除してから投入する。id も 1 から振り直す
  await prisma.$executeRaw`TRUNCATE TABLE choices, questions RESTART IDENTITY`;
  for (const question of questions) {
    await prisma.question.create({
      data: {
        body: question.body,
        explanation: question.explanation,
        choices: {
          create: question.choices.map((choice, index) => ({
            ...choice,
            position: index + 1,
          })),
        },
      },
    });
  }
  console.log(`Seeded ${questions.length} questions`);
}

try {
  await main();
} finally {
  await prisma.$disconnect();
}
