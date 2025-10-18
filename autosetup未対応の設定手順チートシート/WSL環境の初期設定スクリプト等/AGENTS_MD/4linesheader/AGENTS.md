<!--
1) Path: .codex/AGENTS.md
2) What: Unified agent guide (principles + quickstart + ops + templates + UI + data)
3) Why: Single-source, daily-ready, 80/20-aligned execution guide
4) RELEVANT FILES: (self-contained)
-->

# AGENTS.md

## Quickstart (10 lines) / クイックスタート（10行）
1) **Do exactly what’s asked. No more, no less.**  
   依頼どおりに実行（**過不足なし**）。
2) **Prefer minimal, simple solutions (80/20).**  
   **最小・シンプル（80/20）**を最優先。
3) **Read the whole target + related files before editing.**  
   編集前に**対象＋関連ファイル**を全文読む。
4) **Start with a tiny working prototype.**  
   まず**小さく動くプロトタイプ**から。
5) **Add the 4-line header to every file.**  
   全ファイルに**4行ヘッダ**必須。
6) **Small, focused commits; 1 PR = 1 purpose.**  
   **小粒コミット／1PR=1目的**。
7) **Comment non-obvious logic; use clear identifiers.**  
   **自明でない箇所にコメント**／明快な命名。
8) **Risky ops: present reason + alternatives + rollback before acting.**  
   危険操作は**理由・代替・ロールバック**を**事前提示**。
9) **Capture rationale in headers + PR body.**  
   意図は**ヘッダ＋PR本文**に残す。
10) **Push to GitHub only with explicit user approval.**  
    GitHub への push は**明示承認がある場合のみ**。

---

## GOAL (Purpose) / 目的
- Help produce **clean, simple, readable, modular, well-documented** code.  
  **クリーン／シンプル／読みやすい／モジュール化／十分に文書化**されたコードを支援。
- Think with **senior-developer judgment**; avoid over-engineering.  
  **シニア開発者の判断基準**で思考し、過剰設計を避ける。

## MODUS OPERANDI (How we work) / 作法
- Prioritize **simplicity + minimalism**; show **tiny runnable examples** when useful.  
  **シンプル＆ミニマル**最優先。必要に応じ**最小実行例**を示す。
- When uncertain: **prototype → observe → adjust**.  
  迷ったら**試作→観察→調整**。

## ROLES / 関与者
- **User (human)**: directs project, final decisions.  
  **ユーザー**：指揮・最終決定。
- **Human devs**: contribute as needed.  
  **人間開発者**：必要時に実装支援。
- **VS Code (AI copilot)**: IDE assist, moderate autonomy.  
  **VS Code（AI コパイロット）**：IDE 補助、中程度の自律性。
- **AI agents (e.g., Codex/Claude Code)**: multi-file edits, tests, Git ops, refactors.  
  **AIエージェント**：複数ファイル編集・テスト・Git・大規模リファクタ。

## SCOPE & RESTRICTIONS / 範囲と制約
- **Push only on explicit instruction.**  
  **明示指示がある場合のみ push**。
- **No scope creep**: extra ideas go to **proposals**, not implementation.  
  **要求外は実装せず**、価値があれば**提案**に分離。

## VERSION CONTROL / バージョン管理
- Small, meaningful commits; style **`<type>: <summary>`**.  
  小粒で意味のあるコミット；形式 **`<type>: <summary>`**。
- **1 PR = 1 purpose**; diffs must be reviewable.  
  **1PR=1目的**；レビューしやすい差分。

## FILE HEADER (4 lines) / ヘッダ（4行）
1) Path / ファイルパス  
2) What / 何をするか  
3) Why / なぜ存在するか  
4) RELEVANT FILES: 2–4 files / 関連 2〜4 ファイル  
> **Never delete these headers.** / **削除禁止**

## COMMENTS / コメント
- State where/what at top; comment **non-obvious logic**.  
  先頭で所在と役割を明示；**自明でない箇所**にコメント。
- Clear English identifiers; Japanese comments welcome.  
  英語の明快な識別子＋日本語コメントで補足可。

## READING FIRST / まず読む
- Read the **entire file + related files** before edits.  
  **全文＋関連**を読んでから編集。

## SIMPLICITY / シンプルさ
- **SIMPLE = Good, COMPLEX = Bad**; minimize LOC without harming readability.  
  **SIMPLE=善／COMPLEX=悪**；可読性を損なわず LOC を抑制。

## DECISION GUIDE / 判断ガイド
1) **Resilience > Speed**, unless a small 80/20 delivers clear value.  
   **壊れにくさ＞速さ**（小さな 80/20 で価値が出るなら先に出す）。
2) If the explanation grows long, **ship smaller → observe**.  
   説明が長くなるなら**小さく出して観察**。
3) Nice-to-haves belong in **proposals**, not scope.  
   余剰は**提案**へ（スコープ外）。

---

## Operational Details / 運用詳細

### Checklists / チェックリスト
**Before Change / 変更前**  
- [ ] Restate request in **1–2 lines** / **1〜2行**で依頼を言い換え  
- [ ] List **related files + impact** / **関連ファイルと影響**を列挙  
- [ ] Check **spec/UI/API** diffs / **仕様・UI・API**差分を確認  

**During Implementation / 実装時**  
- [ ] Start from **minimal viable change** / **最小実装**から  
- [ ] Apply **4-line header, comments, naming** / **4行ヘッダ・コメント・命名**順守  
- [ ] Actionable errors per policy / **行動可能なエラーメッセージ**  

**Test & Verify / テスト・検証**  
- [ ] Unit tests: happy/sad/boundary / 正常・異常・境界  
- [ ] Brief manual check notes / 手動確認メモ  
- [ ] UI: before/after screenshots when feasible / UIはスクショ  

**Before PR / PR 前**  
- [ ] ≤ 3 bullets summary / 要点 **3項以内**  
- [ ] Why this is **80/20** / **80/20**の理由  
- [ ] Rollback note (1–2 lines) / **ロールバック**（1〜2行）

### Risky-Change Protocol / 危険変更プロトコル
- **Risk types**: data loss, security, broad refactor, infra change.  
  **リスク**：データ喪失・セキュリティ・大規模リファクタ・インフラ変更。
- **Before acting**:  
  1) reason & alternatives  2) blast radius & rollback  3) phased rollout plan  
  **実施前**：①理由と代替案 ②影響範囲とロールバック ③段階導入計画
- **Approval**: explicit user OK.  
  **承認**：ユーザーの明示同意。

### Quality Gates / 品質ゲート
- Mandatory: **fmt / lint / unit**.  
  必須：**fmt / lint / unit**。
- E2E/integration: scale to impact.  
  E2E/統合：影響に応じ軽量運用。
- Record rationale in headers + PR body.  
  意図は**ヘッダ＋PR本文**に記録。

### Knowledge Capture / 知識の蓄積
- Decisions → headers + PR; link issues if any.  
  決定事項→**ヘッダ＋PR**に記録、必要なら課題にリンク。

---

## Templates / 雛形

### File Header (4 lines) / ファイルヘッダ（4行）
```txt
// Path: <repo-relative path>
// What: <what this file provides, in one short line>
// Why : <design intent / rationale, one short line>
// RELEVANT FILES: <2–4 related files>
```

### PR Title / PRタイトル
```
feat: minimal implementation of X (separates Y, simplifies Z)
```

### PR Body (minimal) / PR本文（最小）
- **Summary**: Add/change ○○.  
  **要約**：○○を追加／変更。  
- **80/20**: Why this design is sufficient now.  
  **80/20**：今この設計で十分な理由。  
- **Impact**: API/UI changes or migrations?  
  **影響**：API／UI変更・移行の有無。  
- **Rollback**: `revert <sha>` or flip `<flag>`.  
  **ロールバック**：`revert <sha>` または `<flag>` 切替。

### Commit Message / コミットメッセージ
- Style: **`<type>: <summary>`** (e.g., `fix: replace panic with Result`).  
  形式：**`<type>: <summary>`**（例：`fix: panic を Result に変更`）。

### Review Shortlist / レビュー要点
- Scope fits request? / 依頼の範囲内？  
- Minimal & readable? / 最小で読みやすい？  
- Tests cover happy/sad/boundary? / 正常・異常・境界？  
- Rationale captured? / 意図の記録は十分？

---

## UI Guide (Essentials) / UIガイド（要点）
- **Simple, clean, minimal**; reduce cognitive load.  
  **シンプル／クリーン／ミニマル**で認知負荷を下げる。
- Reference: Apple / ChatGPT.  
  参考：Apple／ChatGPT。
- **Color**: base **black/white**; accent **deep blue**; neutral grays (avoid bluish grays).  
  **色**：基本**黒／白**、アクセント**濃い青**、灰はニュートラル（青み灰は避ける）。
- **Spacing & Type**: consistent rhythm (4/8px), short headings, short sentences.  
  **余白・文字**：一貫したリズム（4/8px）、短い見出し、短文。

---

## Data Policy (DB) / データポリシー（DB）
- **Authority**: DB changes are executed **only by the user**.  
  **権限**：DB変更の実行は**ユーザーのみ**。
- **Proposals**: if needed, provide reason, schema diff, migration sketch, risk & rollback.  
  **提案**：必要時は理由・スキーマ差分・移行案・リスク＆ロールバックを提示。
- **Safety**: backups before change; define rollback (down migration or restore); phase risky changes.  
  **安全策**：事前バックアップ、**ロールバック**定義、段階導入で影響を限定。

---

## Boot (optional) / 起動用（任意）
**One-liner to paste at startup** / **起動直後に貼るワンライナー**  
```
Read ./.codex/AGENTS.md now and follow it strictly; then reply with (a) 3 key rules, (b) the next 3 steps, and (c) one-line risks+rollback.
```
（日本語補助）  
```
いま ./.codex/AGENTS.md を読み、厳守してください。読了後に (a) 規範3点 (b) 次の3手 (c) リスク＋ロールバック1行 を返答してください。
```

---

## GLOSSARY / 用語
- **80/20**: maximum impact with minimal effort.  
  **80/20**：最小の労力で最大の効果。
- **APPU**: Active Paying Power Users (business-side metric).  
  **APPU**：有料で能動的に使うパワーユーザー数（事業指標）。
- **Minimal implementation**: small, robust core that satisfies the request.  
  **最小実装**：依頼を満たす**小さく壊れにくい核**。
