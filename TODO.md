# TODO

## 営業相談チャット プロンプト実装
- [x] `classify_intent` と RAG フェッチ分岐を実装し、`ChatPromptBuilder` が General/Product のパスを切り替えられるようにする
- [x] `ChatPromptBuilder` のユニットテスト（各 Intent、RAG 取得失敗時の挙動など）を追加する
- [ ] RAG 結果の要約・`source_id` 付与・構造化ログ出力を行う共通コンポーネントを整備する
