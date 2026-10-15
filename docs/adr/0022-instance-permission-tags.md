# ADR-0022: インスタンスの権限分離に定義済みタグを使う

- **Status**: Proposed
- **Date**: 2026-10-15
- **Deciders**: Yusaku

## Context

Phase 7 Step 10 で、アプリ用の Compute VM を追加する（ADR-0001）。これにより compartment 内の Compute Instance が 2 台になる。

既存の Dynamic Group `tbcamp-db-instances` のマッチングルールは以下である。

```
All {instance.compartment.id = '<tbcamp の OCID>'}
```

Step 8 で `resource.compartment.id` では Compute Instance にマッチしないことが判明し、`instance.compartment.id` に修正した経緯がある。この属性は Compute Instance 専用のため `resource.type` の指定が不要になった一方、**compartment 内のすべての Compute Instance に一致する**。

このままアプリ VM を追加すると、アプリ VM が自動的にこのグループに属し、DB VM 向けの権限をすべて継承する。

| ポリシー文 | アプリ VM にとって |
| ---------- | ------------------ |
| `read secret-family` | 必要 |
| `read objects` on `tbcamp-config` | 必要 |
| `read buckets` | 無害 |
| **`manage objects` on `tbcamp-pg-backups`** | **不要かつ危険** |

アプリは LB 経由でインターネットに公開される。侵害された場合、PostgreSQL のバックアップを削除・改ざんできる状態になる。バックアップは復旧の最終手段であり、ここを失うと後がない。

また、OCIR からの pull に必要な `read repos` は Container Instance 用の Dynamic Group に付与されており、VM には効かない。どのみち付与先の見直しが必要である。

## Decision

**定義済みタグ（Defined Tags）で Dynamic Group を分離する。**

### 作成するもの

| リソース | 値 |
| -------- | -- |
| タグ名前空間 | `tbcamp` |
| タグキー | `role` |
| タグ値 | `db`（PostgreSQL VM） / `app`（アプリ VM） |

### マッチングルール

<!-- Docs: https://docs.oracle.com/en-us/iaas/Content/Identity/dynamicgroups/Writing_Matching_Rules_to_Define_Dynamic_Groups.htm -->

```
tbcamp-db-instances:
All {instance.compartment.id = '<tbcamp の OCID>', tag.tbcamp.role.value = 'db'}

tbcamp-app-instances:
All {instance.compartment.id = '<tbcamp の OCID>', tag.tbcamp.role.value = 'app'}
```

`matching_rule` は更新可能な属性のため、**既存の Dynamic Group を再作成せずに書き換えられる**。グループ名はそのまま使え、権限が途切れる瞬間も生じない。

`tbcamp-app-instances` はこれまで Container Instance 用（`resource.type = 'computecontainerinstance'`）だったが、マッチングルールを書き換えてアプリ VM 用に転用する。

### ポリシーの振り分け

| 文 | 付与先 |
| -- | ------ |
| `read secret-family` | db / app の両方 |
| `read objects` on `tbcamp-config` | db / app の両方 |
| `read buckets` | db |
| `manage objects` on `tbcamp-pg-backups` | **db のみ** |
| `read repos`（OCIR の pull） | **app のみ** |

## Alternatives Considered

### compartment 全体にマッチさせたまま、過剰な権限を許容する

- **不採用理由**:
  - アプリが侵害された場合にバックアップを失う。影響が復旧不能な領域に及ぶ
  - 「後で分離する」という先送りは、Phase 8 の引き継ぎ項目がすでに 15 件以上あり、実行されない可能性が高い
  - Dynamic Group 名が実態と食い違い、読み手を誤らせる

### `instance.id` でインスタンスごとに Dynamic Group を分ける

マッチングルールにインスタンスの OCID を直接書く方式。

- **不採用理由**:
  - **インスタンスを作ってからでないと Dynamic Group を作れない**。初回起動時の cloud-init が Vault からシークレットを取得できなくなる
  - インスタンスが置き換わるたびに OCID が変わり、同じ問題が再発する

### ポリシーに `request.principal.id` の条件を付けて絞る

- **不採用理由**: 上と同じく OCID との結合が生じ、インスタンス置き換え時に権限が切れる

### Dynamic Group の名前を実態に合わせて改名する（`tbcamp-compute-instances` 等）

- **不採用理由**:
  - `name` は更新不可で、Dynamic Group の再作成を伴う
  - ポリシーは Dynamic Group を名前の文字列で参照しているため、再作成の順序によっては apply が失敗する
  - 分離そのものは行われず、問題は残る

## Consequences

### Positive

- アプリ VM がバックアップバケットへの書き込み権限を持たなくなる
- Dynamic Group の再作成が不要で、権限が途切れる瞬間がない
- グループ名と実態が一致する
- 今後インスタンスを追加する際、タグを付けるだけで適切な権限が付与される

### Negative / Trade-off

- **タグ名前空間は単純に削除できない**。廃止（retire）してからの削除になるため、作成は後戻りしにくい
- IAM の変更には反映のラグがある。apply 直後にバックアップ cron が 1 回失敗する可能性がある
- 既存の PostgreSQL VM に `defined_tags` を追加する変更が入る（その場更新で、VM の再作成は発生しない）

### Neutral

- フリーフォームタグはマッチングルールで参照できない。既存のフリーフォームタグ（`app` / `managed-by` / `role`）は表示・整理の用途として残し、権限制御には定義済みタグを使う
- タグ名前空間はコンパートメント単位のリソースであり、`tbcamp` compartment に配置する
