if vim.g.loaded_herdr_context_sender then
  return
end
vim.g.loaded_herdr_context_sender = true

vim.api.nvim_create_user_command("HerdrSendSelection", function()
  require("herdr-context-sender").send_selection()
end, { range = true })

vim.api.nvim_create_user_command("HerdrSendBuffer", function()
  require("herdr-context-sender").send_buffer()
end, {})

vim.api.nvim_create_user_command("HerdrSendPrompt", function()
  require("herdr-context-sender").send_prompt()
end, {})
