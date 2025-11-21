# ExpertKnowledge System Design

このドキュメントは、営業太郎 における **ExpertKnowledge**（先輩営業マンのナレッジ）機能のシステム構成とデータフローを整理したものです。音声・動画・資料をアップロードして書き起こし、RAG で活用できるようになるまでの全体像を俯瞰できます。

## 1. ドメイン概要

- **SalesExpert**
  - 製品 (`Product`) に紐づく先輩営業マン。
  - `has_many :expert_knowledges`。
- **ExpertKnowledge**
  - 先輩営業が登録するナレッジ本体。Active Storage でファイルを保持。
  - テキスト / ドキュメント / 音声 / 動画をサポート（`ALLOWED_EXTENSIONS` 参照）。
  - メタ情報: `content_type`（商談録音 / 動画 / テキストなど）、`file_name`、`upload_user_id`。
- **TranscriptionJob / Transcription / TranscriptionSegment**
  - 音声・動画ファイルを AWS Transcribe で文章化するための中間テーブル。
  - `Transcription` が全文テキストと構造化 JSON、`TranscriptionSegment` が話者区間を保持。
- **ExpertKnowledgeFile**
  - `TranscriptionSegment` をテキストファイルに束ねた派生テーブル。
  - `txt_body` / `segment_count` / `gemini_file_status` / `gemini_file_id` などを保持し、Gemini File Search へのアップロード状態を追跡する。

## 2. アップロード〜保存

1. 製品詳細画面 (`products/show`) から SalesExpert ごとにファイルを direct upload。
2. `ExpertKnowledge` でバリデーション・保存。
   - `file_presence` / `file_type_allowlist` / `file_size_within_limit` で制約チェック。
   - `before_validation :sync_file_name` で `file_name` を Active Storage の実ファイル名へ同期。
3. `after_create_commit :enqueue_transcription_if_media`
   - 拡張子が `mp3/wav/m4a/mp4/mov` の場合のみ音声書き起こしジョブを投入。
   - PDF など静的ファイルはこの工程をスキップし、必要に応じて別途テキスト抽出ロジックを追加できる。

## 3. 書き起こしパイプライン

```
ExpertKnowledge (音声/動画)
      ↓ after_create_commit
TranscribeAudioJob
      ↓ (AWS Transcribe)
CheckTranscriptionStatusJob → ProcessTranscriptionResultJob
      ↓
Transcription / TranscriptionSegment
      ↓ after_create_commit
TextRefineTranscriptionJob
      ↓
KnowledgeTranscriptBundlerJob
      ↓
Gemini::SyncExpertKnowledgeFileJob
      ↓
Gemini File Search Store
```

### 3.1 TranscribeAudioJob
- S3 URI を生成 (Active Storage が S3 利用必須)。
- AWS Transcribe `start_transcription_job` を呼び出し、`TranscriptionJob` レコードを `processing` に更新。
- 30 秒後に `CheckTranscriptionStatusJob` を予約。

### 3.2 CheckTranscriptionStatusJob
- `get_transcription_job` でステータスをポーリング。
- `COMPLETED` なら `ProcessTranscriptionResultJob` を実行、`FAILED` なら `transcription_status` を `failed` へ更新。

### 3.3 ProcessTranscriptionResultJob
- Transcript JSON を取得して `Transcription` と `TranscriptionSegment` を生成。
- 話者ラベルを `SpeakerIdentifier` で人間向けに補正（できない場合はラベルを維持）。
- ExpertKnowledge の `transcription_status` を `completed` にし、完了日時を記録。
- 続けて `TextRefineTranscriptionJob`・`KnowledgeTranscriptBundlerJob` を通じて Gemini 連携用 txt を準備する。

### 3.4 TextRefineTranscriptionJob
- `Transcription` 作成後に実行。
- OpenAI（設定されていれば）またはヒューリスティックで文面を校正し、読みやすい文章に整える。
- 全文だけでなく各 `TranscriptionSegment` も対象。

## 4. Gemini File Search 連携

### 4.1 SalesExpert ごとの FileSearchStore
- 先輩営業 (`SalesExpert`) 単位で Gemini File Search の `fileSearchStores` を 1 つ割り当てる。
- `sales_experts` テーブルに `gemini_store_id`・`gemini_store_state`（`pending` / `ready` / `failed`）を追加し、`GeminiFileSearchClient#create_store` で生成した ID を保持する。
- Expert が削除された場合は `delete_store` を呼び出し、Gemini 側の不要なリソースをクリーンアップする。

### 4.2 TranscriptionSegment の txt 生成
- `Transcription` 完了後に `KnowledgeTranscriptBundlerJob` を起動し、対象 `ExpertKnowledge` に紐づく `TranscriptionSegment` を 1 つの txt ファイルへ連結する。
- フォーマットは `[mm:ss-mm:ss] SpeakerName: 発話内容` の 1 行構成とし、冒頭にファイル名や撮影日などのメタ情報をヘッダーとして追加する。これにより発話者・内容・時系列が明示される。
- 生成ファイルは一時ディレクトリに保存しつつ、`expert_knowledge_files` テーブルで `txt_body` / `segment_count` / `txt_generated_at` を追跡する。

### 4.3 Gemini へのアップロード
- `Gemini::SyncExpertKnowledgeFileJob` が txt を `GeminiFileSearchClient#upload_file_to_store` 経由でアップロードし、レスポンスの `document` 名や `operation` 名を `expert_knowledge_files` に同期する。
- 同一ナレッジを更新した場合は、最新 txt を再アップロードし、旧 Document を削除したうえで置き換える。
- API のステータスが `PROCESSING` の間はオペレーションをポーリングし、完了後に `gemini_file_status` を `ready` へ更新する。

### 4.4 Expert RAG（検索）
- チャット回答では `ExpertRag` を経由して `GeminiFileSearchClient#query_document` を呼び出す。
- `SalesExpert` が未指定の場合は `gemini_store_id` を持つ全先輩から最大 3 名を補完し、それぞれの Store を横断検索してスコア上位から 3 件を採用する。
- Gemini のレスポンスには抜粋テキストと `chunk_uri` が含まれるため、UI 出典リンクは `chunk_uri` + タイムスタンプ（txt 内ヘッダーから算出）で表示する。

## 5. UI とアクセシビリティ

- 製品詳細画面
  - SalesExpert カードに Gemini 連携ステータス (`gemini_store_state`) と txt 生成日を表示し、失敗時は再実行ボタンを提供する。
  - Transcription 閲覧画面から「Gemini 送信用テキストを確認」リンクを配置し、生成された txt をブラウザでプレビューできるようにする。
- チャット画面サイドバー
  - 各先輩カードに最新の Gemini 反映日時を表示し、出典リンクは Gemini の `chunk_uri` をベースにした「参考: 先輩RAG（mm:ss〜）」形式に更新する。

## 6. エラー処理とステータス

- `KnowledgeTranscriptBundlerJob`・`Gemini::SyncExpertKnowledgeFileJob` で例外が発生した場合は `gemini_store_state` / `gemini_file_status` を `failed` に設定し、UI から再試行できるようにする。
- Gemini API へのリクエスト失敗は `Gemini::Error` としてラップし、再試行可能なステータスコード（429/5xx）は Exponential backoff で最大 5 回リトライする。
- `ExpertRag` は Store 未作成時にフォールバック文を返し、「先輩ナレッジがまだインデックス化されていない」ことを明示する。

## 7. 今後の拡張ポイント

- **複数ファイルサポート**: txt 以外に PDF/スライドも同じ Store にアップロードし、Gemini のマルチモーダル検索を活用する。
- **自動クレンジング**: 長大な書き起こしを分割して複数 txt に分け、Store の上限（現状 32MB）を超えないようにする。
- **検索ログ連携**: Gemini から返る `citations` を `RetrievalTrace` 的なテーブルに保存し、検索品質を継続的にモニタリングできるようにする。

---

この設計により、先輩営業マンが登録した音声・動画ナレッジを自動でテキスト化し、チャット回答に引用できる状態までノーコードでつながっています。拡張時は上記コンポーネントとジョブチェーンを基盤として活用してください。
