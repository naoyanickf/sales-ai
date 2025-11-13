# Google Gemini File Search API — Documents 完全版ドキュメント

## 概要
`fileSearchStores.documents` は、File Search Store 内の **Document（ドキュメント）** を管理・検索するための API です。  
ドキュメントは複数のチャンク（Chunk）に分割され、検索対象となるセマンティック情報の元となります。

---

# 1. Document リソース

```
fileSearchStores/{file_search_store_id}/documents/{document_id}
```

## フィールド一覧

| フィールド名 | 型 | 説明 |
|--------------|----|------|
| **name** | string | ドキュメントの完全リソース名（Immutable） |
| **displayName** | string | 任意入力。人間が読みやすい表示名（最大512文字） |
| **customMetadata[]** | object | 任意入力。ユーザー定義のメタデータ（最大20エントリ） |
| **updateTime** | Timestamp | 出力専用。最終更新時刻（RFC3339） |
| **createTime** | Timestamp | 出力専用。作成時刻（RFC3339） |
| **state** | enum | ドキュメントの処理状態 |
| **sizeBytes** | int64 | 取り込まれたファイルサイズ |
| **mimeType** | string | MIME タイプ |

---

# 2. Document の状態（State Enum）

| State | 説明 |
|--------|------|
| **STATE_UNSPECIFIED** | デフォルト値 |
| **STATE_PENDING** | 一部チャンクの処理中 |
| **STATE_ACTIVE** | 全チャンク処理完了、検索可能 |
| **STATE_FAILED** | 一部チャンクの処理に失敗 |

---

# 3. API メソッド

---

## 3.1 Delete — ドキュメント削除

### エンドポイント
```
DELETE https://generativelanguage.googleapis.com/v1beta/{name=fileSearchStores/*/documents/*}
```

### パラメータ
| 名称 | 説明 |
|------|------|
| **name (必須)** | 削除対象の Document の完全リソース名 |
| **force (任意)** | `true` なら関連する Chunk も含めて完全削除 |

### レスポンス
```
{}
```

---

## 3.2 Get — ドキュメント取得

### エンドポイント
```
GET https://generativelanguage.googleapis.com/v1beta/{name=fileSearchStores/*/documents/*}
```

### 説明
指定した Document のメタデータを返す。

### レスポンス例
```json
{
  "name": "...",
  "displayName": "...",
  "customMetadata": [],
  "updateTime": "...",
  "createTime": "...",
  "state": "STATE_ACTIVE",
  "sizeBytes": "10240",
  "mimeType": "application/pdf"
}
```

---

## 3.3 List — ドキュメント一覧取得

### エンドポイント
```
GET https://generativelanguage.googleapis.com/v1beta/{parent=fileSearchStores/*}/documents
```

### パラメータ

| パラメータ | 説明 |
|-----------|------|
| **parent（必須）** | 対象ストア名 |
| **pageSize** | デフォルト 10、最大 20 |
| **pageToken** | 次ページ取得用 |

### レスポンス例
```json
{
  "documents": [
    { "name": "...", "displayName": "...", "state": "STATE_ACTIVE" }
  ],
  "nextPageToken": "..."
}
```

---

## 3.4 Query — セマンティック検索

### エンドポイント
```
POST https://generativelanguage.googleapis.com/v1beta/{name=fileSearchStores/*/documents/*}:query
```

### リクエストボディ

```json
{
  "query": "string",
  "resultsCount": 10,
  "metadataFilters": [
    {
      "key": "chunk.custom_metadata.year",
      "conditions": [
        { "intValue": 2020, "operation": "GREATER_EQUAL" },
        { "intValue": 2010, "operation": "LESS" }
      ]
    }
  ]
}
```

### フィルタルール
- **stringValue** → OR のみ
- **intValue** → AND が可能

### レスポンス例

```json
{
  "relevantChunks": [
    {
      "chunk": { "name": "...", "content": "..." },
      "relevanceScore": 0.92
    }
  ]
}
```

---

# 4. Chunk オブジェクト（参考）

| フィールド | 説明 |
|-----------|------|
| **name** | チャンク ID |
| **content** | 変換後のテキスト |
| **customMetadata** | メタデータ |
| **sizeBytes** | チャンクサイズ |

---

# 5. RelevantChunk オブジェクト

| フィールド | 説明 |
|-----------|------|
| **chunk** | Chunk 本体 |
| **relevanceScore** | 関連度スコア（0〜1） |

---

# 6. 認証（OAuth）

各リクエストに以下を付与：

```
-H "Authorization: Bearer $(gcloud auth print-access-token)"
```

---

# 7. コードサンプル

---

## Python — Query

```python
from google import genai

client = genai.Client()

response = client.file_search_stores.documents.query(
    name="fileSearchStores/my-store/documents/my-doc",
    body={
        "query": "explain the architecture",
        "resultsCount": 5
    }
)

for c in response["relevantChunks"]:
    print(c["relevanceScore"], c["chunk"]["content"])
```

---

## Curl — Get Document

```bash
curl -H "Authorization: Bearer $TOKEN"   "https://generativelanguage.googleapis.com/v1beta/fileSearchStores/my-store/documents/my-doc"
```

---

## Curl — Query

```bash
curl -X POST   -H "Authorization: Bearer $TOKEN"   -H "Content-Type: application/json"   -d '{
        "query": "What is semantic retrieval?",
        "resultsCount": 5
      }'   "https://generativelanguage.googleapis.com/v1beta/fileSearchStores/my-store/documents/my-doc:query"
```

---

# 8. ライセンス
- ドキュメント：**CC BY 4.0**
- コードサンプル：**Apache 2.0**

---

最終更新：**2025-11-06**

---

# 9. Rails 実装メモ

- `app/services/gemini_file_search_client.rb` が FileSearchStore / Document API を呼ぶための最小クライアントです。
- 代表的な呼び出し例

```ruby
client = GeminiFileSearchClient.new
store = client.create_store(display_name: "Product Docs")
store_name = store["name"] #=> "fileSearchStores/abc123"

client.list_documents(store_name: store_name, page_size: 20)
client.query_document(store_name: store_name, document_id: "doc-123", query: "料金プラン", results_count: 3)
client.delete_store(store_name, force: true)
```

- 具体的な使い方やメソッド一覧は `GEMINI_FILE_SEARCH_CLIENT_USAGE.md` にまとめています。
