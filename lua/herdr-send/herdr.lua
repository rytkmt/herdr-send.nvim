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

      -- The agent NAME must be unique across workspaces, otherwise herdr
      -- rejects the start with "agent_name_taken". Scope it to the current
      -- workspace to avoid clashing with agents of the same kind elsewhere.
      -- NAME must be 1-32 chars, start with a lowercase letter and contain
      -- only lowercase letters, digits, '-' or '_', so sanitize it.
      local workspace_id = vim.env.HERDR_WORKSPACE_ID
      local agent_name = opts.agent_cmd
      if workspace_id and workspace_id ~= "" then
        agent_name = opts.agent_cmd .. "-" .. workspace_id
      end
      agent_name = agent_name:lower():gsub("[^a-z0-9_-]", "-"):sub(1, 32)

      local start_args = {
        "herdr", "agent", "start", agent_name,
        "--kind", opts.agent_cmd,
        "--pane", new_pane_id,
      }

      local start_output = {}
      vim.fn.jobstart(start_args, {
        stdout_buffered = true,
        on_stdout = function(_, start_data)
          start_output[#start_output + 1] = table.concat(start_data, "")
        end,
        on_exit = function(_, start_exit_code)
          local output = table.concat(start_output, "")

          -- herdr may report failures as a JSON error on stdout even when the
          -- process exit code is 0, so inspect both.
          local decoded_ok, decoded = pcall(vim.json.decode, output)
          if decoded_ok and decoded and decoded.error then
            local msg = decoded.error.message or decoded.error.code or "unknown error"
            vim.notify("[herdr-send] Failed to start agent: " .. msg, vim.log.levels.ERROR)
            return
          end

          if start_exit_code ~= 0 then
            vim.notify("[herdr-send] Failed to start agent (exit code: " .. start_exit_code .. ")", vim.log.levels.ERROR)
            return
          end

          callback({ pane_id = new_pane_id, agent = opts.agent_cmd })
        end,
      })
    end,
  })
end

return M
