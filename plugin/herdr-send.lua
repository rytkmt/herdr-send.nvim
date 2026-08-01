if vim.g.loaded_herdr_send then
  return
end
vim.g.loaded_herdr_send = true

vim.api.nvim_create_user_command("HerdrSendSelection", function()
  require("herdr-send").send_selection()
end, { range = true })

vim.api.nvim_create_user_command("HerdrSendBuffer", function()
  require("herdr-send").send_buffer()
end, {})

vim.api.nvim_create_user_command("HerdrSendPrompt", function()
  require("herdr-send").send_prompt()
end, {})
