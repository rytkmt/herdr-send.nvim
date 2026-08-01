local M = {}

M.defaults = {
  agent_cmd = "claude",
  split_direction = "right",
  split_ratio = 0.5,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
