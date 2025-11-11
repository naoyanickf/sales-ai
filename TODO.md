# TODO
- [x] WorkSpace関連の実装　イメージとしては、Userが最初にログインしたあとで、WorkSpaceが一つも存在しなければ、WorkSpace名を入力させるかたちで、最初の一つを作成させる
  - [x] Workspaceモデルの実装
  - [x] WorkspaceUserモデル（中間テーブル）の実装
  - [x] ユーザーとワークスペースの関連付け
  - [x] 役割（管理者/参加者）
- [x] WorkSpace管理画面を用意してほしい。要件として、そのWorkSpaceの管理者しかアクセスできない。
  - [x] 名前の変更ができる。
  - [x] WorkSpaceの削除ができる。削除時には、deleted_atを埋めるだけの簡易仕様。ワークスペース名を入力させて、破壊的な確認をする。
