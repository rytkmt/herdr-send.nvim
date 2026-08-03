local M = {}

function M.get_workspace_agents(callback)
  local workspace_id = vim.env.HERDR_WORKSPACE_ID
  local my_pane_id = vim.env.HERDR_PANE_ID

  if not workspace_id then
    vim.notify("[herdr-send] HERDR_WORKSPACE_ID not set. Are you running inside herdr?", vim.log.levels.ERROR)
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
        vim.notify("[herdr-send] herdr error: " .. err, vim.log.levels.ERROR)
      end
    end,
  })
end

function M.send_text(pane_id, text, callback)
  vim.fn.jobstart({ "herdr", "pane", "send-text", pane_id, text .. " " }, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.fn.jobstart({ "herdr", "agent", "focus", pane_id })
      else
        vim.notify("[herdr-send] Failed to send (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
      end
      if callback then
        callback(exit_code)
      end
    end,
  })
end

function M.submit_prompt(pane_id, text, callback)
  vim.fn.jobstart({ "herdr", "agent", "prompt", pane_id, text }, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.notify("[herdr-send] Failed to send (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
      end
      if callback then
        callback(exit_code)
      end
    end,
  })
end

function M.start_agent(opts, callback)
  local my_pane_id = vim.env.HERDR_PANE_ID
  if not my_pane_id then
    vim.notify("[herdr-send] HERDR_PANE_ID not set", vim.log.levels.ERROR)
    return
  end

  local split_args = {
    "herdr", "pane", "split", my_pane_id,
    "--direction", opts.split_direction,
    "--ratio", tostring(opts.split_ratio),
    "--no-focus",
  }

  vim.fn.jobstart(split_args, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local output = table.concat(data, "")
      if output == "" then
        vim.notify("[herdr-send] Failed to split pane", vim.log.levels.ERROR)
        return
      end

      local ok, parsed = pcall(vim.json.decode, output)
      if not ok or not parsed.result or not parsed.result.pane or not parsed.result.pane.pane_id then
        vim.notify("[herdr-send] Failed to parse split result", vim.log.levels.ERROR)
        return
      end

      local new_pane_id = parsed.result.pane.pane_id

      vim.fn.jobstart({ "herdr", "agent", "start", opts.agent_cmd, "--kind", opts.agent_cmd, "--pane", new_pane_id }, {
        on_exit = function(_, start_exit_code)
          if start_exit_code ~= 0 then
            vim.notify("[herdr-send] Failed to start agent (exit code: " .. start_exit_code .. ")", vim.log.levels.ERROR)
            return
          end
          callback({ pane_id = new_pane_id })
        end,
      })
    end,
  })
end

return M
