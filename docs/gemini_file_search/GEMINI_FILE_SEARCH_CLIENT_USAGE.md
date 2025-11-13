# GeminiFileSearchClient の使い方

`app/services/gemini_file_search_client.rb` は Google Gemini File Search の FileSearchStore / Document API を呼ぶための最小クライアントです。Rails コンソールやジョブから以下のように利用します。

## 1. 事前準備

- `GOOGLE_AI_STUDIO_API_KEY`（必須）を環境変数に設定
- 任意で `GEMINI_HTTP_TIMEOUT` / `GEMINI_HTTP_OPEN_TIMEOUT` を秒数で上書き可能（既定 20s / 5s）

```bash
export GOOGLE_AI_STUDIO_API_KEY=your-key
```

## 2. FileSearchStore の操作

```ruby
client = GeminiFileSearchClient.new

# Store 作成
resp = client.create_store(display_name: "Product A Docs")
store_name = resp["name"] # => "fileSearchStores/abc123"

# 一覧
client.list_stores(page_size: 20)

# 取得
client.get_store(store_name)

# 削除（関連 Document もまとめて削除する場合は force: true）
client.delete_store(store_name, force: true)
```

## 3. Document の操作

```ruby
# ドキュメント一覧（store_name は "fileSearchStores/xxx" 形式でも ID だけでも OK）
client.list_documents(store_name: store_name, page_size: 20)

# メタデータ取得
client.get_document(store_name: store_name, document_id: "documents/xyz") # ドキュメント ID だけでも可

# 削除
client.delete_document(store_name: store_name, document_id: "doc-123", force: true)

# セマンティック検索（Query）
client.query_document(
  store_name: store_name,
  document_id: "doc-123",
  query: "ベースプランの料金を教えて",
  results_count: 5,
  metadata_filters: [
    {
      key: "chunk.custom_metadata.year",
      conditions: [{ intValue: 2022, operation: "GREATER_EQUAL" }]
    }
  ]
)
```

`query_document` は `relevantChunks` を含むレスポンスを返すため、チャンク本文と `relevanceScore` を UI に表示できます。

## 4. ファイルのアップロード/インポート

### 4.1 直接アップロード（media.uploadToFileSearchStore）

```ruby
File.open("/path/to/doc.pdf", "rb") do |file|
  client.upload_file_to_store(
    store_name: store_name,
    io: file,
    filename: "doc.pdf",
    mime_type: "application/pdf",
    display_name: "営業資料 2024-06",
    custom_metadata: [{ key: "product_id", stringValue: "abc" }],
    chunking_config: {
      "chunkSizeTokens" => 512,
      "maxOverlapTokens" => 32
    }
  )
end
```

レスポンスは長時間実行オペレーション（`operations/*`）なので、`client.get_operation(operation["name"])` で状態をポーリングして完了 (`done: true`) になるのを待ちます。

### 4.2 既存 File（files/*）のインポート

```ruby
client.import_file(
  store_name: store_name,
  file_name: "files/xyz-123",
  custom_metadata: [{ key: "workspace_id", stringValue: "ws-1" }]
)
```

`file_name` は事前に Files API (`files.upload`) でアップロードした ID を指定します。

### 4.3 ProductDocument からのアップロード例

```ruby
client = GeminiFileSearchClient.new
document = ProductDocument.find(123) # 任意の資料
store_name = document.product.gemini_data_store_id # 事前に同期しておく

operation = document.file.open do |io|
  client.upload_file_to_store(
    store_name: store_id,
    io: io,
    filename: document.file.filename.to_s,
    mime_type: document.file.content_type || "application/octet-stream",
    display_name: document.document_name.presence || document.file.filename.to_s,
    custom_metadata: [
      { key: "product_document_id", stringValue: document.id.to_s },
      { key: "product_id",         stringValue: product.id.to_s },
      { key: "workspace_id",       stringValue: product.workspace_id.to_s }
    ],
    chunking_config: {
      "chunkSizeTokens"  => 512,
      "maxOverlapTokens" => 32
    },
    file_size: document.file.blob.byte_size
  )
end

# 進捗確認
loop do
  operation_name = operation['name'].split("/").last
  result = client.get_operation(store_id, operation_name)
  break if result["done"]
  sleep 5
end
```

ActiveStorage の `file.open` は一時ファイルを開き、ブロック内で IO を扱えるため、そのまま `io:` に渡せます。`gemini_data_store_id` が未作成の場合は先に Data Store を用意してから呼び出してください。
