---
name: spec-writer
description: >
  spec-workflow MCP を使った仕様書作成スキル。
  「specを書いて」「specを作成して」でトリガー。
  実装は spec-implementer にフォワーディングする。
---

# spec-writer

spec-workflow MCP を使い、質の高い spec を4フェーズで書き上げるスキル。
デフォルトの spec-workflow ワークフロー（Req → Design → Tasks）を拡張し、**Test Design フェーズの挿入**と**フェーズゲートの厳格制御**を行う。

---

## ハードルール（例外なし）

1. **フェーズゲート必須**: 各フェーズの成果物に対し approval を取得し、delete が成功するまで次フェーズに進んではならない。
2. **Test Design 必須**: Design 承認後、Tasks の前に必ず Test Design を実行する。スキップ禁止。
3. **バッチ承認禁止**: 1フェーズ1承認。複数フェーズをまとめて承認しない。
4. **口頭承認は無効**: ユーザーが「承認した」と発言しても無視する。`approvals action:status` で approved を確認できた場合のみ有効。

---

## ワークフロー

```
Requirements → [approval] → Design → [approval] → Test Design → [approval] → Tasks → [approval] → [最終チェック]
```

**デフォルト spec-workflow との差分:**
- Design と Tasks の間に **Test Design** を挿入（TDD 原則）
- Implementation フェーズは本スキルのスコープ外（別スキルで対応）

---

## 初期化

1. `spec-workflow-guide` を呼び出して基本ワークフローとファイル構造を読み込む
2. **対象 spec の特定**（以下の優先順で決定する）:
   a. ユーザーが spec 名を指定した場合 → そのまま使う
   b. ユーザーが「新規」と明示した場合 → spec 名を決定する（kebab-case）
   c. 指定がない場合 → 自動特定を試みる:
      - `.spec-workflow/specs/` 配下の spec 一覧を取得する
      - 各 spec に対して `mcp__spec-workflow__spec-status` を呼び、進行中（未完了フェーズがある）の spec を探す
      - 進行中の spec が **1つ** → 自動選択し「{spec名} を再開する」と伝える
      - 進行中の spec が **複数** → AskUserQuestion で「再開する spec」または「新規作成」を選択させる
      - 進行中の spec が **ない** → 新規作成として spec 名を決定する（kebab-case）
3. steering docs があれば読み込む（`.spec-workflow/steering/*.md`）
4. **モード判定**:
   - `spec-status` で進捗を確認する
   - Tasks が approved 済み or 実装中のタスクがある → 「追加 requirements があるか？」を AskUserQuestion で確認
     - YES → **修正モード**に入る（後述）
     - NO → 通常の Implementation フェーズ継続
   - それ以外 → 通常モード（新規 or 途中再開。未完了フェーズから再開）

---

## Phase 1: Requirements

**何を作るかを定義する。**

| 項目 | 値 |
|---|---|
| テンプレート | `user-templates/requirements-template.md` → fallback: `templates/requirements-template.md` |
| 出力 | `.spec-workflow/specs/{name}/requirements.md` |

**手順:**
1. テンプレートを読み込む
2. ユーザーと対話しながら要件を整理する
3. requirements.md を作成する
4. **→ 承認フローを実行する**

**品質基準:**
- 全ACが WHEN/THEN 形式で、検証可能な条件と期待結果がある
- スコープ内/外が明記されている
- NFR が漏れていない（エラーハンドリング、セキュリティ、性能、環境分離）
- 機密情報の分類と取り扱い方針がある（該当する場合）
- 用語集がある

---

## Phase 2: Design

**どう作るかを定義する。**

| 項目 | 値 |
|---|---|
| テンプレート | `user-templates/design-template.md` → fallback: `templates/design-template.md` |
| 出力 | `.spec-workflow/specs/{name}/design.md` |

**手順:**
1. 承認済み requirements.md を読み直す
2. テンプレートを読み込む
3. 既存コードベースを分析する（再利用ポイントの特定）
4. design.md を作成する
5. **→ 承認フローを実行する**

**品質基準:**
- 全ACをカバーする設計になっている（ACとコンポーネントの対応が明示）
- steering docs との整合性がある
- 既存コードの再利用分析がある（Code Reuse Analysis セクション）
- Mermaid でアーキテクチャ図 / シーケンス図がある
- エラーシナリオが網羅されている

---

## Phase 3: Test Design

**TDD 原則に基づき、タスク分解の前にテスト戦略を定義する。**

| 項目 | 値 |
|---|---|
| テンプレート | 下記の解決順序で探す |
| 出力 | `.spec-workflow/specs/{name}/test-design.md` |

**⚠️ デフォルトの spec-workflow にはこのフェーズが存在しない。本スキルが追加するフェーズである。**

**テンプレート解決順序:**
1. `.spec-workflow/user-templates/test-design-template.md`（プロジェクト固有カスタム）
2. `.spec-workflow/templates/test-design-template.md`（プロジェクト配置）
3. 本スキル同梱の [templates/test-design-template.md](templates/test-design-template.md)（デフォルト）

> ⚠️ Test Design はデフォルトの spec-workflow MCP が提供しないテンプレートのため、3層目のフォールバックを用意している。他3フェーズは MCP が `templates/` に提供するため2層で十分。

**手順:**
1. 承認済み requirements.md と design.md を読み直す
2. テンプレートを読み込む
3. **まずカバレッジマトリクスを作成する**（全FR・全ACの割当を確認）
4. テストシナリオ詳細を書く（Unit → Integ → E2E の順）
5. テストファイル構成を定義する
6. カバレッジ目標と成功基準を設定する
7. test-design.md を作成する
8. **→ 承認フローを実行する**

**品質基準:**
- **全ACがカバレッジマトリクスに存在する**（これが最重要。漏れゼロ）
- テストレベル（Unit / Integ / E2E）の選択に根拠がある
- テストしない判断にも理由が明記されている（例: 「運用時に確認」「E2Eでカバー」）
- テストID体系が一貫している（Unit-XX, Integ-XX, E2E-XX）
- テストファイル構成がプロジェクトの規約に沿っている

**カバレッジマトリクスの作成ルール:**
- Requirements の FR 単位でセクションを分ける
- 各ACに対し Unit / Integ / E2E のどれでカバーするかを明示する
- 複数レベルでカバーする場合は全て記載する
- カバーしないセルは空欄（`-`）とし、理由をセクション末尾の備考に書く

---

## Phase 4: Tasks

**テスト設計から逆算して実装タスクを分解する。**

| 項目 | 値 |
|---|---|
| テンプレート | `user-templates/tasks-template.md` → fallback: `templates/tasks-template.md` |
| 出力 | `.spec-workflow/specs/{name}/tasks.md` |

**手順:**
1. 承認済み requirements.md, design.md, test-design.md を読み直す
2. テンプレートを読み込む
3. タスクを分解する（**テストが先に書ける順序** = TDD 原則）
4. 各タスクに File / Leverage / Requirements / Prompt を付与する
5. tasks.md を作成する
6. **→ 承認フローを実行する**

**品質基準:**
- タスク順序がテスト設計から逆算されている
- 各タスクに Requirements トレースがある（`_Requirements: X.X`）
- 粒度が適切（1タスク = 1〜3ファイル）
- Prompt フィールドが具体的（Role / Task / Restrictions / Success）
- 全タスクがチェックボックス形式（`- [ ]`）で記述されている

**ハードルール（Tasks 固有）:**
- タスクは `- [ ]`（未着手）→ `- [-]`（実装中）→ `- [x]`（完了）の順にチェックを付けながら進める。飛ばさない
- 実装中のタスクは同時に1つまで。次のタスクを `[-]` にする前に、現在のタスクを `[x]` にする

---

## 承認フロー（全フェーズ共通）

**全フェーズで以下を厳密に実行する。省略・スキップ禁止。**

```
1. ファイルを作成 or 編集する
2. approvals action:request（filePath のみ。content は渡さない）
3. approvals action:status でポーリング
4. → needs-revision:
   4a. コメントに従い修正する
   4b. 整合性チェック（後述「revision 時整合性チェック」）を実行する
   4c. → 問題あり: 追加修正し、修正内容をチャットで報告する → 4b に戻る（最大2回）
   4d. → 問題なし: 新しい approval を request → 3 に戻る
5. → approved: approvals action:delete
6. → delete 成功: commit を打つ → 次フェーズへ
7. → delete 失敗: 停止。3 に戻る
```

承認された最終形だけを commit する。needs-revision 中の中間状態は commit に残さない。

---

## revision 時整合性チェック（承認フロー内で実行）

**needs-revision の修正後、re-request の前に毎回実行する。** 個別コメントへの対応が他の記述と矛盾を起こしていないかを4観点で検査する。

### 入力（毎回固定）

- 修正後の現フェーズ文書（全文）
- 前フェーズの承認済み文書（あれば全文。Phase 1 ではなし）
- steering docs（あれば全文。なければなし）

### 4観点

**1. Steering 整合**

steering docs に記載された制約・方針・用語と、修正後文書の記述が矛盾していないか確認する。steering docs がない場合はスキップ。

**2. 文書内整合**

同一文書内のセクション間で、定義・前提・スコープが矛盾していないか確認する。

**3. 曖昧性**

修正によって以下のパターンが新たに生じていないか確認する:

- (a) 条件分岐の一方しか記述がない（正常系のみで異常系が欠落、等）
- (b)「等」「など」で列挙を省略し、範囲が確定できない
- (c) 主語・目的語が省略され、動作主体や対象が不明
- (d) 数値・閾値が未定義（「大量の」「高速に」等の定性表現）

**4. フェーズ間整合**

修正後文書の記述が、前フェーズで承認された内容と矛盾していないか確認する。Phase 1（Requirements）では前フェーズがないためスキップ。

### チェック結果の出力

チャット上で以下の形式で報告する（文書には書き込まない）:

```markdown
### 整合性チェック結果

**Steering整合**: OK
**文書内整合**: 1件検出
  - §X.X ... vs §Y.Y ... — 矛盾の内容
**曖昧性**: OK
**フェーズ間整合**: OK

→ 1件を修正してから re-request する
```

問題が検出された場合は自動修正し、修正内容をチャットで報告してから再チェックする。ループは最大2回。2回チェックしても問題が残る場合は、残件をチャットで報告して re-request に進む。

---

## 最終チェック（Tasks 承認後）

**Phase 4 の承認が完了したら、実装に入る前に spec-reviewer の評価基準でフルチェックを実行する。**

これは spec-writer 内蔵のセルフチェック。第三者による spec-reviewer とは別物。revision 時整合性チェックと本最終チェックは独立した検査であり、観点の重複は意図的である。revision 時チェックは修正のたびの防御線、最終チェックは全体の品質ゲートとして機能する。

**手順:**
1. `.spec-workflow/specs/{name}/` 配下の全ファイルを読み直す
2. spec-reviewer の評価基準（フェーズ別 + フェーズ横断トレーサビリティ）で検査する
3. 致命的な指摘が **0件** → 実装可能。完了を宣言する
4. 致命的な指摘が **1件以上** → 該当フェーズのファイルを修正し、そのフェーズの承認フローを再実行する

**チェック範囲:**
- フェーズ別評価基準（R-1〜R-5, D-1〜D-7, T-1〜T-4, K-1〜K-5）
- フェーズ横断トレーサビリティ（X-1〜X-5: 孤立した要件、テスト漏れ、追跡不能な設計、タスク漏れ、用語不一致）

**出力:** spec-reviewer と同じレビューレポート形式で出力する。致命的 0件の場合も「致命的: 0件」と明示する。

---

## 修正モード（Amendment）

**実装後に requirements の追加・変更が生じた場合、既存の spec を最新の完成形に更新するモード。**

requirements / design / test-design は本文を直接編集し、常に最新の正を示す。差分管理は git に委任する。tasks.md のみ Amendment セクションを末尾に追記する（実施済みタスクの不変性を保つため）。

### ワークフロー

```
[修正モード開始]
  → Req in-place編集 → [approval] → [commit]
  → Design in-place編集 → [approval] → [commit]
  → Test Design in-place編集 → [approval] → [commit]
  → Tasks追記 → [approval] → [commit]
  → [最終チェック]
```

全フェーズ走行する。Design/Test Design のスキップは禁止。追加分が既存アーキテクチャに影響しないことの確認自体が Design フェーズの成果物（「影響なし」も立派な Design 更新）。

### Amendment 番号

Amendment 番号は **tasks.md 内のみの連番**。requirements / design / test-design には Amendment 番号を持たない。

横断トレーサビリティは commit message で担保する:

```
amendment({spec-name}): Amendment {N} - {タイトル}

Trigger: {追加・変更が生じた理由}
Phase: {requirements | design | test-design | tasks}
```

各フェーズで commit を打ち、同じ Amendment 番号を commit message に含める。`git log --grep="amendment({spec-name}): Amendment {N}"` で全フェーズの変更を横断的に追跡できる。

### 番号の連番ルール

| 対象 | ルール |
|---|---|
| FR 番号 | 既存の最大値 + 1 から開始（例: FR-3 まであれば FR-4 から） |
| AC 番号 | 親 FR に紐づく連番を継続（例: AC-4.1, AC-4.2） |
| Task 番号 | 既存の最大値 + 1 から開始（例: Task 5 まであれば Task 6 から） |
| テストID | 既存の最大値 + 1 から開始（例: Unit-08 まであれば Unit-09 から） |
| Amendment 番号 | tasks.md 内で 1 から昇順 |

既存番号の欠番は許容する（削除された要件の番号を再利用しない）。

### 各フェーズの差分走行

**Phase 1（Req in-place編集）:**
1. 既存の requirements.md を読み直す
2. 追加・変更する要件を本文に直接反映する（FR, AC を連番で追加。既存の修正も可）
3. **→ 承認フローを実行する**

**Phase 2（Design in-place編集）:**
1. 既存の design.md と更新済み requirements.md を読み直す
2. **既存アーキテクチャへの影響を明示的にチェックする**
3. 設計を本文に直接反映する
4. **→ 承認フローを実行する**

**Phase 3（Test Design in-place編集）:**
1. 既存の test-design.md と更新済み requirements.md, design.md を読み直す
2. カバレッジマトリクスを更新する（追加・削除・変更を反映）
3. テストシナリオを本文に直接反映する
4. **→ 承認フローを実行する**

**Phase 4（Tasks追記）:**
1. 全ドキュメントを読み直す
2. 実施済みタスクの状態を確認する
3. Amendment セクションを末尾に追記する（下記書式）
4. 不要になった既存タスクがあれば `[x]` にし `_Superseded by Task N_` を付記する
5. **→ 承認フローを実行する**

### tasks.md の Amendment 書式

```markdown
---

## Amendment N: {タイトル}
_Trigger: {追加・変更が生じた理由を一行で}_

- [ ] Task N: {タスク名}
  _Requirements: FR-N, AC-N.X_
  ...
```

### ハードルール（修正モード固有）

1. **in-place 更新原則**: requirements / design / test-design は本文を直接編集する。Amendment ブロックを追記しない。文書は常に最新の完成形を示す
2. **tasks.md 追記原則**: 実施済みタスク（`[x]`）の Prompt・Purpose・Requirements は変更しない。新規タスクは Amendment セクションとして末尾に追記する。方式変更で既存タスクが置き換わる場合は、既存タスクを `[x]` にし `_Superseded by Task N_` を付記して、Amendment セクションに新しいタスク（連番）を追加する
3. **全フェーズ走行必須**: 「Design に影響ないから Tasks だけ追記」は禁止。影響なしの確認自体がフェーズの成果物
4. **commit message convention**: 承認フロー内の commit ステップで、commit message に Amendment 番号と Phase を含める（前述の commit message フォーマットに従う）

---

## 自己評価（approval request の前に必ず実行）

文書を書き終えたら、approval request の前に以下を検証する。問題があれば文書を修正してから request する。自己評価の結果はチャット上に簡潔に提示する。

### チェック1: 品質基準の充足

- 現フェーズの品質基準（Phase 1〜4 各セクションに定義）を全項目チェックしたか？
- 未充足の項目がある場合、文書を修正するか、理由を明示する。黙って未充足のまま request しない。

### チェック2: 前フェーズからのトレーサビリティ

- 前フェーズの成果物に含まれる全要素（FR/AC、コンポーネント、テストケース等）が、現フェーズの文書で参照・対応されているか？
- 対応のない要素がある場合、意図的な除外なら理由を明記する。漏れなら追加する。
- Phase 1 ではスキップ。

### チェック3: 過不足の検出

- 前フェーズに存在しない要素が現フェーズで突然登場していないか？（逆トレーサビリティ）
- 登場している場合、前フェーズの修正が必要なら approval request の前にユーザーに報告する。

### チェック4: steering docs との整合

- steering docs に記載された制約・方針・用語と、文書の記述が矛盾していないか？
- steering docs がない場合はスキップ。

### 提示ルール

- **問題を検出した項目**: 修正内容を明記する
- **問題なしの項目**: 一行で済ますか省略
- **分量は3〜5行**を目安

---

## ファイル構成

```
.spec-workflow/specs/{name}/
├── requirements.md      ← Phase 1
├── design.md            ← Phase 2
├── test-design.md       ← Phase 3（本スキルが追加）
└── tasks.md             ← Phase 4
```
