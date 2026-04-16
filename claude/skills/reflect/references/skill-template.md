# スキル作成テンプレート

スキル化提案の適用時、SKILL.mdの作成は公式 `/skill-creator` に委譲する。
reflectは検出した情報（概要・検出理由・ワークフロー案）をコンテキストとしてまとめ、skill-creatorに渡す役割を担う。

## スキル作成フロー

1. reflectがスキル化提案のコンテキスト（概要・検出理由・想定ワークフロー）をまとめる
2. `/skill-creator` を呼び出し、コンテキストを渡す
3. skill-creatorがインタビュー→SKILL.md生成→テスト→改善ループを実行
4. 完了後、reflectが `CLAUDE.md` の「利用可能なスキル」と `README.md` を更新

## ディレクトリ構造（参考）

```
.claude/skills/[skill-name]/
├── SKILL.md
└── references/       # 必要に応じて
    └── *.md
```

## ルールファイルのフォーマット

[公式ドキュメント](https://code.claude.com/docs/en/memory#modular-rules-with-clauderules)準拠。

### ディレクトリ構造

```
.claude/rules/
├── [ルール名].md           # 全ファイルに適用
├── frontend/
│   └── react.md            # サブディレクトリでグループ化可能
└── backend/
    └── api.md
```

### 基本フォーマット（全ファイル適用）

```markdown
APIエンドポイントには必ずバリデーションを入れること
```

- frontmatterなし = 全ファイルに常時適用
- 1ルール1ファイル
- ファイル名は内容を表す日本語（例: `コードコメント禁止.md`）
- 内容は簡潔に、1-5行程度

### 条件付きルール（特定ファイルにスコープ）

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "lib/**/*.ts"
---

APIエンドポイントには必ずバリデーションを入れること
```

- `paths` フィールドでglobパターン指定
- 対象ファイルを操作する時だけ適用される

### pathsで使えるglobパターン

| パターン | マッチ対象 |
|----------|-----------|
| `**/*.ts` | 全ディレクトリのTypeScriptファイル |
| `src/**/*` | src/以下の全ファイル |
| `*.md` | プロジェクトルートのMarkdownファイル |
| `src/**/*.{ts,tsx}` | .tsと.tsx両方（ブレース展開） |
| `{src,lib}/**/*.ts` | srcとlib両方のTS（ブレース展開） |
