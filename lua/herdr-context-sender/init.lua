local config = require("herdr-context-sender.config")
local herdr = require("herdr-context-sender.herdr")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

local function select_agent_and_send(text)
  herdr.get_workspace_agents(function(agents)
    vim.schedule(function()
      if #agents == 0 then
        vim.notify("[herdr-context-sender] No agents found in this workspace", vim.log.levels.WARN)
        return
      end

      local function send(agent)
        local prompt = text
        if config.options.prefix ~= "" then
          prompt = config.options.prefix .. "\n" .. prompt
        end
        herdr.send_prompt(agent.pane_id, prompt)
      end

      if #agents == 1 then
        send(agents[1])
        return
      end

      vim.ui.select(agents, {
        prompt = "Select agent:",
        format_item = function(agent)
          return (agent.terminal_title_stripped or agent.pane_id) .. " [" .. (agent.agent_status or "unknown") .. "]"
        end,
      }, function(selected)
        if selected then
          send(selected)
        end
      end)
    end)
  end)
end

function M.send_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getregion(start_pos, end_pos, { type = vim.fn.visualmode() })
  local text = table.concat(lines, "\n")

  if text == "" then
    vim.notify("[herdr-context-sender] No selection", vim.log.levels.WARN)
    return
  end

  if config.options.include_filepath then
    local filepath = vim.fn.expand("%:p")
    if filepath ~= "" then
      text = "File: " .. filepath .. "\n\n" .. text
    end
  end

  select_agent_and_send(text)
end

function M.send_buffer()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")

  if text == "" then
    vim.notify("[herdr-context-sender] Buffer is empty", vim.log.levels.WARN)
    return
  end

  if config.options.include_filepath then
    local filepath = vim.fn.expand("%:p")
    if filepath ~= "" then
      text = "File: " .. filepath .. "\n\n" .. text
    end
  end

  select_agent_and_send(text)
end

function M.send_prompt()
  vim.ui.input({ prompt = "Prompt: " }, function(input)
    if not input or input == "" then
      return
    end
    select_agent_and_send(input)
  end)
end

return M
