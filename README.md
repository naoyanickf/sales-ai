# 営業支援AIチャットシステム仕様書

## サービス概要

### サービス名
SalesAI Assistant（仮）

### コンセプト
生成AIとRAG技術を活用し、企業の営業ノウハウを蓄積・活用・教育できる営業支援SaaSプラットフォーム

### ミッション
営業担当者が「こんなとき何を言えばいいか」迷わない世界を実現する

## コア概念

### 1. ワークスペース
- **定義**: サービスの契約・課金単位
- **特徴**: 
  - 個人または法人が所有
  - 複数ユーザーの招待可能
  - プラン別の機能制限（Free/Standard/Premium）

### 2. 製品
- **定義**: 企業が販売する商品・サービスの単位
- **特徴**:
  - ワークスペース内に複数作成可能
  - 営業資料・ナレッジの集約単位
  - 製品別のAI学習

### 3. 先輩営業マン
- **定義**: 製品別のトップセールスマンのペルソナを持つAIエージェント
- **特徴**:
  - 実在の営業マンの知識・話法を学習
  - 製品ごとに複数登録可能
  - 音声・動画・テキストから学習

## 主要機能

### 1. 営業相談チャット
- 製品を選択して質問
- AIアシスタントまたは特定の先輩営業マンが回答
- 過去の会話履歴を保存・検索

### 2. ナレッジ管理
- **製品資料**: PDF、Word、Excel、PowerPointのアップロード
- **営業トーク**: 音声・動画ファイルの文字起こしと学習
- **自動同期**: S3アップロード時にKnowledge Base自動更新

### 3. 学習システム
- **RAG（Retrieval-Augmented Generation）**:
  - Amazon Bedrock Knowledge Base使用
  - ベクトルデータベースで高速検索
  - コンテキストに応じた回答生成

## ユーザーフロー

### 初回利用
1. ワークスペース作成
2. 製品登録
3. 営業資料アップロード
4. （任意）先輩営業マン作成
5. チャットで相談開始

### 日常利用
1. 製品を選択
2. （任意）相談相手を選択
3. 営業の悩みを質問
4. AIが過去の成功事例やベストプラクティスを基に回答

## 技術仕様

### アーキテクチャ
- **フロントエンド**: React + Bootstrap
- **バックエンド**: Ruby on Rails API
- **AI基盤**: Amazon Bedrock + Claude 3
- **ストレージ**: Amazon S3
- **ベクトルDB**: Amazon OpenSearch Serverless
- **音声処理**: Amazon Transcribe

### データモデル（簡略版）
```
Workspace
  └── User（多対多）
  └── Product
      ├── ProductDocument
      └── SalesExpert
          └── ExpertKnowledge

Conversation
  ├── User
  ├── Product
  ├── SalesExpert（任意）
  └── Message
```

## 差別化要素

1. **製品別のナレッジ管理**: 製品ごとに最適化された回答
2. **ペルソナ型AI**: 実在の営業マンの話法を再現
3. **マルチモーダル学習**: 音声・動画・文書を統合的に学習
4. **日本の営業文化対応**: 関係構築重視の営業スタイルに対応

## システム設計 - 必要なオブジェクト

### 1. ワークスペース関連

#### Workspace（ワークスペース）
- id: ワークスペースID
- name: ワークスペース名
- owner_type: 所有者タイプ（個人/法人）
- owner_name: 所有者名
- plan: プラン（無料/スタンダード/プレミアムなど）
- is_active: 有効/無効
- created_at: 作成日時
- updated_at: 更新日時

#### WorkspaceUser（ワークスペースユーザー）
- id: ID
- workspace_id: ワークスペースID
- user_id: ユーザーID
- role: 役割（管理者/メンバー/閲覧者）
- joined_at: 参加日時

### 2. ユーザー関連

#### User（ユーザー）
- id: ユーザーID
- email: メールアドレス
- password: パスワード（ハッシュ化）
- name: 氏名
- created_at: 作成日時
- updated_at: 更新日時

### 3. 製品関連

#### Product（製品）
- id: 製品ID
- workspace_id: ワークスペースID
- name: 製品名
- description: 製品説明
- category: カテゴリ
- is_active: 有効/無効
- created_at: 作成日時
- updated_at: 更新日時

#### ProductDocument（製品資料）
- id: 資料ID
- product_id: 製品ID
- document_name: 資料名
- document_type: 資料タイプ（営業資料/FAQ/価格表/提案書など）
- file_name: ファイル名
- file_type: ファイルタイプ（PDF/PPT/DOCX/CSV）
- file_url: ファイル保存先URL
- upload_user_id: アップロードユーザーID
- created_at: 作成日時

### 4. 先輩営業マン関連

#### SalesExpert（先輩営業マン）
- id: エキスパートID
- product_id: 製品ID
- name: 名前（例：山田太郎）
- title: 肩書（例：トップセールス、〇〇エリア担当）
- description: 説明（経歴、得意分野など）
- avatar_url: アバター画像URL
- is_active: 有効/無効
- created_at: 作成日時
- updated_at: 更新日時

#### ExpertKnowledge（エキスパート知識）
- id: 知識ID
- expert_id: エキスパートID
- content_type: コンテンツタイプ（商談録音/動画/テキスト）
- file_name: ファイル名
- file_url: ファイル保存先URL
- transcript: 文字起こしテキスト
- metadata: メタデータ（JSON - 商談相手、日付、成約有無など）
- upload_user_id: アップロードユーザーID
- created_at: 作成日時

### 5. 対話関連

#### Conversation（会話）
- id: 会話ID
- user_id: ユーザーID
- product_id: 製品ID
- expert_id: エキスパートID（nullの場合は一般アシスタント）
- title: 会話タイトル
- created_at: 作成日時
- updated_at: 更新日時

#### Message（メッセージ）
- id: メッセージID
- conversation_id: 会話ID
- role: 役割（user/assistant）
- content: メッセージ内容
- created_at: 作成日時

### 6. 学習データ関連

#### EmbeddingData（埋め込みデータ）
- id: 埋め込みID
- workspace_id: ワークスペースID
- source_type: ソースタイプ（product_document/expert_knowledge）
- source_id: ソースID
- chunk_text: テキストチャンク
- embedding_vector: ベクトルデータ
- metadata: メタデータ（JSON）
- created_at: 作成日時

### 関係性

#### 基本構造
1. Workspace ← 1:N → Product
2. Workspace ← N:N → User (WorkspaceUser経由)
3. Product ← 1:N → ProductDocument
4. Product ← 1:N → SalesExpert
5. SalesExpert ← 1:N → ExpertKnowledge

#### 対話関連
1. User ← 1:N → Conversation
2. Product ← 1:N → Conversation
3. SalesExpert ← 1:N → Conversation
4. Conversation ← 1:N → Message

#### 学習データ
1. Workspace ← 1:N → EmbeddingData
2. ProductDocument → EmbeddingData
3. ExpertKnowledge → EmbeddingData