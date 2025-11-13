# Google Gemini File Search Stores API ドキュメント（要約版）
**更新日**: 2025-11-12 21:14 JST

このドキュメントは、Google Gemini API の **File Search** 機能のうち **File Search Stores** に関する REST エンドポイントを日本語で要約したものです。  
元ページ: https://ai.google.dev/api/file-search/file-search-stores

---

## 概要
**File Search API** は、Google のインフラを用いた RAG（Retrieval Augmented Generation）向けのホスト型検索・QA サービスです。  
ここでは、索引のコンテナとなる **FileSearchStore** の作成・取得・一覧・削除、ならびに **ファイルの取り込み／アップロード** について解説します。

- **ベース URL**: `https://generativelanguage.googleapis.com/v1beta`
- **認証**: Google AI Studio の API キー（`x-goog-api-key` またはクエリ `?key=`）。必要に応じて OAuth のスコープが要求されることがあります。
- **リソース名の形式**: `fileSearchStores/{filesearchstore}` 例: `fileSearchStores/my-file-search-store-123`

> 以降の `curl` 例は API キーを **環境変数 `GEMINI_API_KEY`** に格納している前提です。

---

## メソッド一覧

### 1) File を Store に**アップロード**（前処理 & チャンク分割）
**Method**: `media.uploadToFileSearchStore`  
**目的**: バイナリを直接アップロードして、そのまま前処理・チャンク化して Store 内の Document として保存する。

- **Upload URI（メディア付き）**  
  `POST https://generativelanguage.googleapis.com/upload/v1beta/{{fileSearchStoreName=fileSearchStores/*}}:uploadToFileSearchStore`

- **Metadata URI（メタデータのみ）**  
  `POST https://generativelanguage.googleapis.com/v1beta/{{fileSearchStoreName=fileSearchStores/*}}:uploadToFileSearchStore`

**Path パラメータ**
- `fileSearchStoreName`（必須）: 例 `fileSearchStores/my-file-search-store-123`

**Request Body（JSON）**
- `displayName`: 生成される Document の表示名（任意）
- `customMetadata[]`: 任意のメタデータ（任意）
- `chunkingConfig`: チャンク方法の設定（省略時は既定値）（任意）
- `mimeType`: データの MIME タイプ（省略時は自動推定）（任意）

**Response**
- 長時間実行オペレーション（LRO; `Operation` 型）。`done` が `true` になると `response` か `error` が入る。

**curl（単純アップロードの例：メタデータ + バイナリ）**
```bash
curl -X POST   -H "x-goog-api-key: $GEMINI_API_KEY"   -H "Content-Type: application/json; charset=utf-8"   --data '{"displayName":"Annual Report","mimeType":"application/pdf"}'   "https://generativelanguage.googleapis.com/upload/v1beta/fileSearchStores/my-file-search-store-123:uploadToFileSearchStore?uploadType=media"   --data-binary "@./report.pdf"
```

---

### 2) **FileSearchStore を作成**
**Method**: `fileSearchStores.create`  
`POST /v1beta/fileSearchStores`

**Request Body**
- `displayName`（任意、最大 512 文字）

**Response**
- 作成された `FileSearchStore` リソース

**curl**
```bash
curl -X POST   -H "x-goog-api-key: $GEMINI_API_KEY"   -H "Content-Type: application/json"   -d '{"displayName":"Docs on Semantic Retriever"}'   "https://generativelanguage.googleapis.com/v1beta/fileSearchStores"
```

---

### 3) **FileSearchStore を取得**
**Method**: `fileSearchStores.get`  
`GET /v1beta/{{name=fileSearchStores/*}}`

**Path**
- `name`（必須）: 例 `fileSearchStores/my-file-search-store-123`

**Response**
- 該当 `FileSearchStore`

**curl**
```bash
curl -H "x-goog-api-key: $GEMINI_API_KEY"   "https://generativelanguage.googleapis.com/v1beta/fileSearchStores/my-file-search-store-123"
```

---

### 4) **FileSearchStore 一覧**
**Method**: `fileSearchStores.list`  
`GET /v1beta/fileSearchStores`

**Query**
- `pageSize`（任意，既定 10，最大 20）
- `pageToken`（任意）

**Response**
- `fileSearchStores[]`: `FileSearchStore` の配列（作成時間の昇順で並び替え）
- `nextPageToken`: 次ページ取得トークン

**curl**
```bash
curl -H "x-goog-api-key: $GEMINI_API_KEY"   "https://generativelanguage.googleapis.com/v1beta/fileSearchStores?pageSize=20"
```

---

### 5) **FileSearchStore を削除**
**Method**: `fileSearchStores.delete`  
`DELETE /v1beta/{{name=fileSearchStores/*}}`

**Path**
- `name`（必須）

**Query**
- `force`（任意，`true` なら関連する Document などもまとめて削除。既定は `false`）

**Notes**
- `force=false` で Store に Document が残っている場合は `FAILED_PRECONDITION` が返る。

**curl**
```bash
curl -X DELETE   -H "x-goog-api-key: $GEMINI_API_KEY"   "https://generativelanguage.googleapis.com/v1beta/fileSearchStores/my-file-search-store-123?force=true"
```

---

### 6) **File Service から Store にインポート**
**Method**: `fileSearchStores.importFile`  
`POST /v1beta/{{fileSearchStoreName=fileSearchStores/*}}:importFile`

**Path**
- `fileSearchStoreName`（必須）: 例 `fileSearchStores/my-file-search-store-123`

**Request Body**
- `fileName`（必須）: 例 `files/abc-123`（File Service 側で作成した `files/*`）
- `customMetadata[]`（任意）
- `chunkingConfig`（任意）

**Response**
- 長時間実行オペレーション（`Operation`）

**curl**
```bash
curl -X POST   -H "x-goog-api-key: $GEMINI_API_KEY"   -H "Content-Type: application/json"   -d '{"fileName":"files/abc-123"}'   "https://generativelanguage.googleapis.com/v1beta/fileSearchStores/my-file-search-store-123:importFile"
```

---

## Operation（長時間実行）
多くの書き込み系メソッドは **`Operation`** を返します。  
代表的なフィールド:
- `name`: オペレーション名（`operations/{id}` で終わる）
- `metadata`: 進捗などの実装依存メタデータ（`@type` を含むことがある）
- `done`: `false`=進行中 / `true`=完了
- `error`: 失敗時の `Status`
- `response`: 成功時のレスポンス（メソッドに依存）

---

## 参考情報 / 実装ヒント
- **チャンク分割（`chunkingConfig`）**を与えない場合は、サービス既定の分割パラメータが用いられます。
- **`mimeType`** は省略可能ですが、精度や前処理に影響し得るため、分かっている場合は明示指定を推奨します。
- **`force` 削除**は不可逆です。関連 Document を含めて一括削除されます。
- アップロードとインポートの違い  
  - *アップロード*: クライアントから直接バイナリを送る（`uploadToFileSearchStore`）  
  - *インポート*: 既に **File Service** にある `files/*` を取り込む（`importFile`）

---

## 用語
- **FileSearchStore**: 検索対象ドキュメント群を保持する論理コンテナ
- **Document**: Store に格納される単位（アップロード／インポート時に生成）
- **File Service**: `files/*` を管理する別リソース群（`importFile` で参照）

## Rails 実装メモ

`app/services/gemini_file_search_client.rb` が FileSearchStore 向けの簡易クライアントです。例:

```ruby
client = GeminiFileSearchClient.new
client.create_store(display_name: "Product Docs")
client.list_stores(page_size: 5)
client.delete_store("fileSearchStores/my-store", force: true)
```

API キーは `GOOGLE_AI_STUDIO_API_KEY`（必須）、タイムアウトは `GEMINI_HTTP_TIMEOUT` / `GEMINI_HTTP_OPEN_TIMEOUT` で調整します。

---

## 変更履歴
- 2025-11-12: 初版（この要約は `v1beta` 仕様に基づく）
