# LocalBoxAssistant

`LocalBoxAssistant` は iOS で動くローカル LLM アプリの土台です。UI は SwiftUI、ローカル推論エンジンは MLX 系ライブラリを前提にしています。

## 含まれるもの
- SwiftUI チャット UI
- ローカル推論サービス層（`MLXChatService`）
- XcodeGen ベースのプロジェクト定義（`project.yml`）
- GitHub Actions での署名なし IPA 生成（AltStore 配布向け）

## セットアップ
1. XcodeGen をインストール
2. プロジェクト生成
3. Xcode で開いて実行

```bash
brew install xcodegen
xcodegen generate
open LocalBoxAssistant.xcodeproj
```

## GitHub Actions での成果物
`Build Unsigned IPA` ワークフローを実行すると、Artifacts に `LocalBoxAssistant-unsigned.ipa` が出力されます。

## MLX 実装について
- `MLXLMCommon` / `MLXLLM` / `MLX` を利用して実際にテキスト生成
- 初回メッセージ送信時に Hugging Face からモデルファイルをダウンロード
- ローカル保存ディレクトリを `ModelConfiguration(directory:)` でロード
- 2回目以降はモデルコンテナをメモリキャッシュして再利用

### Hugging Face ダウンロード先
- `Application Support/Models/<repo-idを--置換した名前>/`

### 既定モデル
- `mlx-community/Qwen2.5-1.5B-Instruct-4bit`

必要なら `MLXChatService` 初期化時に `HFModelConfig` を差し替えて、`repoID` / `revision` / `files` / `token` を変更できます。
