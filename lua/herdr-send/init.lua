local config = require("herdr-send.config")
local herdr = require("herdr-send.herdr")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

local function get_relative_path()
  local filepath = vim.fn.expand("%:p")
  if filepath == "" then
    return nil
  end
  local cwd = vim.fn.getcwd()
  if filepath:sub(1, #cwd) == cwd then
    return filepath:sub(#cwd + 2)
  end
  return filepath
end

local at_prefix_agents = { claude = true, gemini = true }

local function format_file_ref(rel_path, line_spec)
  local prefix = at_prefix_agents[config.options.agent_cmd] and "@" or ""
  if line_spec then
    return prefix .. rel_path .. "#L" .. line_spec
  end
  return prefix .. rel_path
end

local function resolve_agent_and_run(send_fn)
  herdr.get_workspace_agents(function(agents)
    vim.schedule(function()
      if #agents == 0 then
        vim.notify("[herdr-send] Starting agent...", vim.log.levels.INFO)
        herdr.start_agent(config.options, function(agent)
          vim.schedule(function()
            send_fn(agent)
          end)
        end)
        return
      end

      if #agents == 1 then
        send_fn(agents[1])
        return
      end

      vim.ui.select(agents, {
        prompt = "Select agent:",
        format_item = function(agent)
          return (agent.terminal_title_stripped or agent.pane_id) .. " [" .. (agent.agent_status or "unknown") .. "]"
        end,
      }, function(selected)
        if selected then
          send_fn(selected)
        end
      end)
    end)
  end)
end

function M.send_selection()
  local rel_path = get_relative_path()
  if not rel_path then
    vim.notify("[herdr-send] No file", vim.log.levels.WARN)
    return
  end

  local start_line = vim.fn.getpos("'<")[2]
  local end_line = vim.fn.getpos("'>")[2]

  local line_spec
  if start_line == end_line then
    line_spec = tostring(start_line)
  else
    line_spec = start_line .. "-" .. end_line
  end
  local ref = format_file_ref(rel_path, line_spec)

  resolve_agent_and_run(function(agent)
    herdr.send_text(agent.pane_id, ref)
  end)
end

function M.send_buffer()
  local rel_path = get_relative_path()
  if not rel_path then
    vim.notify("[herdr-send] No file", vim.log.levels.WARN)
    return
  end

  resolve_agent_and_run(function(agent)
    herdr.send_text(agent.pane_id, format_file_ref(rel_path))
  end)
end

function M.send_prompt()
  vim.ui.input({ prompt = "Prompt: " }, function(input)
    if not input or input == "" then
      return
    end
    resolve_agent_and_run(function(agent)
      herdr.submit_prompt(agent.pane_id, input)
    end)
  end)
end

return M
