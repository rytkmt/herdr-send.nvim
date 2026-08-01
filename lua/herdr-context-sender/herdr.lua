local M = {}

function M.get_workspace_agents(callback)
  local workspace_id = vim.env.HERDR_WORKSPACE_ID
  local my_pane_id = vim.env.HERDR_PANE_ID

  if not workspace_id then
    vim.notify("[herdr-context-sender] HERDR_WORKSPACE_ID not set. Are you running inside herdr?", vim.log.levels.ERROR)
    return
  end

  vim.fn.jobstart({ "herdr", "agent", "list" }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local output = table.concat(data, "")
      if output == "" then
        callback({})
        return
      end

      local ok, parsed = pcall(vim.json.decode, output)
      if not ok or not parsed.result or not parsed.result.agents then
        callback({})
        return
      end

      local agents = {}
      for _, agent in ipairs(parsed.result.agents) do
        if agent.workspace_id == workspace_id and agent.pane_id ~= my_pane_id then
          table.insert(agents, agent)
        end
      end
      callback(agents)
    end,
    on_stderr = function(_, data)
      local err = table.concat(data, "")
      if err ~= "" then
        vim.notify("[herdr-context-sender] herdr error: " .. err, vim.log.levels.ERROR)
      end
    end,
  })
end

function M.send_prompt(pane_id, text, callback)
  vim.fn.jobstart({ "herdr", "agent", "prompt", pane_id, text }, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify("[herdr-context-sender] Sent to agent", vim.log.levels.INFO)
      else
        vim.notify("[herdr-context-sender] Failed to send (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
      end
      if callback then
        callback(exit_code)
      end
    end,
  })
end

return M
