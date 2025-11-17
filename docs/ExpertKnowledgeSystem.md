# ExpertKnowledge System Design

このドキュメントは、Sales AI における **ExpertKnowledge**（先輩営業マンのナレッジ）機能のシステム構成とデータフローを整理したものです。音声・動画・資料をアップロードして書き起こし、RAG で活用できるようになるまでの全体像を俯瞰できます。

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
- **KnowledgeChunk**
  - RAG 取り込み用に整形したテキストチャンク。
  - `chunk_text` と `metadata`（話者情報など）を保持し、`ExpertRag` で検索対象になる。

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
CreateKnowledgeChunksJob
      ↓
KnowledgeChunk
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
- 続けて `CreateKnowledgeChunksJob` をキューに積む。

### 3.4 TextRefineTranscriptionJob
- `Transcription` 作成後に実行。
- OpenAI（設定されていれば）またはヒューリスティックで文面を校正し、読みやすい文章に整える。
- 全文だけでなく各 `TranscriptionSegment` も対象。

## 4. チャンク生成と RAG

### 4.1 CreateKnowledgeChunksJob / KnowledgeChunker
- `KnowledgeChunker` が校正済みセグメントを順番に束ね、最大 1200 文字 / 30 セグメントを超えたら分割。
- 各チャンクには以下を保存:
  - `chunk_text`: 「話者: 内容」の列挙。
  - `transcription_segment_ids`: 元セグメント ID。UI から該当箇所へリンクする用途。
  - `metadata`: 話者名リスト等を格納。
- 既存チャンクは `delete_all` 後に再作成するため、ナレッジ更新時も最新内容で置き換わる。

### 4.2 RAG 取り込みと検索
- 現状は `KnowledgeChunk` レコードをそのまま検索対象にしており、`ExpertRag.fetch` が実装。
  - BM25 + 文字 n-gram のオーバーラップで一次スコアリング。
  - OpenAI Embeddings が利用可能なら上位 `rerank_top_k` 件をコサイン類似度で再ランキング。
- チャット応答 (`Chats::StreamingResponseService`) 内で、ユーザー発話と紐づく先輩営業が設定されている場合に `ExpertRag.fetch` を呼び出し、上位 3 件を「出典」として回答末尾に添付。
- 将来的なベンダー連携:
  - `UploadToBedrockKnowledgeBaseJob` を用意（未実装）。`KnowledgeChunk` を AWS Bedrock Knowledge Bases 等へ同期する場合に拡張可能。

## 5. UI とアクセシビリティ

- 製品詳細画面
  - SalesExpert カード内で ExpertKnowledge をアップロードし、DirectUpload の進捗表示や書き起こしステータスを確認できる。
  - Transcription が完了すると、書き起こし閲覧画面 (`TranscriptionsController`) から各セグメントを参照可能。
- チャット画面サイドバー
  - 選択中の製品に紐づく SalesExpert / ExpertKnowledge / 資料が一覧化され、ナレッジ資産を探しやすくしている。

## 6. エラー処理とステータス

- ExpertKnowledge `transcription_status`:
  - `pending` → `processing` → `completed` / `failed`
  - UI ではバッジ表示し、`failed` の場合はエラーメッセージを表示。
- ジョブ失敗時
  - 各ジョブで rescue ログ出力。
  - 必ず `transcription_status` を `failed` へ更新して UI が固まらないようにする。
  - AWS SDK が無い環境では NameError を捕捉し、即座に `failed` に落とす。

## 7. 今後の拡張ポイント

- **テキスト/PDF の自動チャンク化**: 現状は音声/動画からの書き起こしを主導。PDF 等も自動テキスト抽出→チャンク化する処理を追加可能。
- **外部ベクトルストア連携**: `UploadToBedrockKnowledgeBaseJob` を実装し、`KnowledgeChunk` を AWS Bedrock や Vertex AI RAG へ連携。
- **再利用 API**: `ExpertRag` を外部 API 化し、チャット以外の画面でも先輩ナレッジ検索を提供できる。

---

この設計により、先輩営業マンが登録した音声・動画ナレッジを自動でテキスト化し、チャット回答に引用できる状態までノーコードでつながっています。拡張時は上記コンポーネントとジョブチェーンを基盤として活用してください。
