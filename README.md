# herdr-context-sender.nvim

同一 [herdr](https://herdr.dev) ワークスペース内の AI エージェントに、Neovim からコンテキストを送信するプラグイン。

## 機能

- ビジュアル選択テキストをエージェントのプロンプトに送信
- バッファ全体をエージェントのプロンプトに送信
- 自由入力プロンプトを `vim.ui.input` 経由で送信
- エージェントが1つなら自動選択、複数あれば `vim.ui.select` で選択

## 要件

- Neovim >= 0.10
- [herdr](https://herdr.dev) >= 0.7.0
- Neovim が herdr ペイン内で動作していること

## インストール

### lazy.nvim

```lua
{
  "rytkmt/herdr-context-sender.nvim",
  config = function()
    require("herdr-context-sender").setup()
  end,
}
```

## 設定

```lua
require("herdr-context-sender").setup({
  -- 送信時にプロンプトへ付加するプレフィックス（デフォルト: ""）
  prefix = "",
  -- 選択/バッファ送信時にファイルパスを含めるか（デフォルト: true）
  include_filepath = true,
})
```

## コマンド

| コマンド | モード | 説明 |
|---------|--------|------|
| `:HerdrSendSelection` | Visual | 選択テキストをエージェントに送信 |
| `:HerdrSendBuffer` | Normal | バッファ全体をエージェントに送信 |
| `:HerdrSendPrompt` | Normal | 自由入力プロンプトをエージェントに送信 |

## キーマップ例

```lua
vim.keymap.set("v", "<leader>hs", "<cmd>HerdrSendSelection<cr>", { desc = "Send selection to herdr agent" })
vim.keymap.set("n", "<leader>hb", "<cmd>HerdrSendBuffer<cr>", { desc = "Send buffer to herdr agent" })
vim.keymap.set("n", "<leader>hp", "<cmd>HerdrSendPrompt<cr>", { desc = "Send prompt to herdr agent" })
```

## 仕組み

1. 環境変数 `$HERDR_WORKSPACE_ID` で現在のワークスペースを特定
2. `herdr agent list` を実行し、同一ワークスペース内のエージェントをフィルタ（Nvim自身のペインは除外）
3. エージェントが1つなら直接送信、複数ならピッカーで選択
4. `herdr agent prompt <pane_id> <text>` でプロンプトを送信

## ライセンス

MIT
