# herdr-send.nvim

同一 [herdr](https://herdr.dev) ワークスペース内の AI エージェントに、Neovim からファイル参照やプロンプトを送信するプラグイン。

## 機能

- ビジュアル選択範囲のファイル参照（`@path#L1-5`）をエージェントのプロンプト欄に入力
- バッファのファイル参照（`@path`）をエージェントのプロンプト欄に入力
- 自由入力プロンプトをエージェントにサブミット
- エージェントが1つなら自動選択、複数あれば `vim.ui.select` で選択
- エージェントが存在しなければ自動でペイン分割して起動

## 対応エージェント

`@path` ファイル参照構文をサポートするエージェント:

- Claude Code
- Gemini CLI

上記以外のherdr対応エージェント（Codex, Copilot, Devin, Kimi 等）にもテキスト送信自体は動作するが、`@` 記法がエージェント側で認識されるかは各エージェントの仕様に依存する。

## 要件

- Neovim >= 0.10
- [herdr](https://herdr.dev) >= 0.7.0
- Neovim が herdr ペイン内で動作していること

## インストール

### lazy.nvim

```lua
{
  "rytkmt/herdr-send.nvim",
  config = function()
    require("herdr-send").setup()
  end,
}
```

## 設定

```lua
require("herdr-send").setup({
  agent_cmd = "claude",       -- 起動するエージェント (デフォルト: "claude")
  split_direction = "right",  -- 分割方向: "right" or "down" (デフォルト: "right")
  split_ratio = 0.5,          -- 分割比率 (デフォルト: 0.5)
})
```

## コマンド

| コマンド | モード | 動作 |
|---------|--------|------|
| `:HerdrSendSelection` | Visual | `@path#L1-5` をプロンプト欄に入力（サブミットなし、フォーカス移動） |
| `:HerdrSendBuffer` | Normal | `@path` をプロンプト欄に入力（サブミットなし、フォーカス移動） |
| `:HerdrSendPrompt` | Normal | 自由入力プロンプトをサブミット（フォーカス移動なし） |

エージェントが同一ワークスペースに存在しない場合、自動でペインを分割してエージェントを起動し、ready後に送信する。

## キーマップ例

```lua
vim.keymap.set("v", "<leader>hs", "<cmd>HerdrSendSelection<cr>", { desc = "Send selection to herdr agent" })
vim.keymap.set("n", "<leader>hb", "<cmd>HerdrSendBuffer<cr>", { desc = "Send buffer to herdr agent" })
vim.keymap.set("n", "<leader>hp", "<cmd>HerdrSendPrompt<cr>", { desc = "Send prompt to herdr agent" })
```

## 仕組み

1. 環境変数 `$HERDR_WORKSPACE_ID` で現在のワークスペースを特定
2. `herdr agent list` を実行し、同一ワークスペース内のエージェントをフィルタ（Nvim自身のペインは除外）
3. エージェントが0件なら `herdr pane split` + `herdr agent start` で自動起動（startコマンドがready待機を内包）
4. エージェントが1つなら直接送信、複数ならピッカーで選択
5. Selection/Buffer: `herdr pane send-text` でプロンプト欄にテキスト入力（末尾スペース付き）+ フォーカス移動
6. Prompt: `herdr agent prompt` でサブミット

## ライセンス

MIT
