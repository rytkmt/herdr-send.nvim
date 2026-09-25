local config = require("herdr-send.config")
local herdr = require("herdr-send.herdr")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

local function get_absolute_path()
  local filepath = vim.fn.expand("%:p")
  if filepath == "" then
    return nil
  end
  return filepath
end

local at_prefix_agents = { claude = true, gemini = true }

local function format_file_ref(agent_name, file_path, line_spec)
  -- Absolute paths start with "/", which some agents (e.g. Kiro) may
  -- mistake for a slash command. Always prefix "@" for absolute paths.
  local is_absolute = file_path:sub(1, 1) == "/"
  local prefix = (is_absolute or at_prefix_agents[agent_name]) and "@" or ""
  if line_spec then
    return prefix .. file_path .. "#L" .. line_spec
  end
  return prefix .. file_path
end

local function agent_label(agent)
  local name = agent.terminal_title_stripped or agent.terminal_title or agent.pane_id
  return name .. " (" .. agent.pane_id .. ")"
end

local function notify_sent(agent, what)
  vim.notify("[herdr-send] Sent " .. what .. " to " .. agent_label(agent), vim.log.levels.INFO)
end

local function pick_agent(agents, prompt, send_fn)
  if #agents == 1 then
    send_fn(agents[1])
    return
  end

  vim.ui.select(agents, {
    prompt = prompt,
    format_item = function(agent)
      return (agent.terminal_title_stripped or agent.pane_id) .. " [" .. (agent.agent_status or "unknown") .. "]"
    end,
  }, function(selected)
    if selected then
      send_fn(selected)
    end
  end)
end

local function start_agent_and_send(send_fn)
  vim.notify("[herdr-send] Starting agent...", vim.log.levels.INFO)
  herdr.start_agent(config.options, function(agent)
    vim.schedule(function()
      send_fn(agent)
    end)
  end)
end

local function resolve_agent_and_run(send_fn)
  herdr.get_workspace_agents(function(agents)
    vim.schedule(function()
      -- No agent in the same workspace: auto-start in this tab.
      if #agents == 0 then
        start_agent_and_send(send_fn)
        return
      end

      local my_tab_id = vim.env.HERDR_TAB_ID
      local same_tab = {}
      local other_tab = {}
      for _, agent in ipairs(agents) do
        if my_tab_id and agent.tab_id == my_tab_id then
          table.insert(same_tab, agent)
        else
          table.insert(other_tab, agent)
        end
      end

      -- Agent(s) exist in the current tab: send there.
      if #same_tab > 0 then
        pick_agent(same_tab, "Select agent:", send_fn)
        return
      end

      -- Only other-tab agents: let the user choose to start a new one here
      -- or send to one of the other-tab agents.
      local START_HERE = { __start_here = true }
      local choices = { START_HERE }
      for _, agent in ipairs(other_tab) do
        table.insert(choices, agent)
      end

      vim.ui.select(choices, {
        prompt = "No agent in this tab. Choose:",
        format_item = function(choice)
          if choice.__start_here then
            return "[Start new agent in this tab]"
          end
          return "→ "
            .. (choice.terminal_title_stripped or choice.pane_id)
            .. " [" .. (choice.agent_status or "unknown") .. "]"
        end,
      }, function(selected)
        if not selected then
          return
        end
        if selected.__start_here then
          start_agent_and_send(send_fn)
        else
          send_fn(selected)
        end
      end)
    end)
  end)
end

function M.send_selection()
  local abs_path = get_absolute_path()
  if not abs_path then
    vim.notify("[herdr-send] No file", vim.log.levels.WARN)
    return
  end

  local mode = vim.fn.mode()
  local start_line, end_line
  if mode:match("[vV\22]") then
    start_line = vim.fn.getpos("v")[2]
    end_line = vim.fn.getpos(".")[2]
  else
    start_line = vim.fn.getpos("'<")[2]
    end_line = vim.fn.getpos("'>")[2]
  end
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local line_spec
  if start_line == end_line then
    line_spec = tostring(start_line)
  else
    line_spec = start_line .. "-" .. end_line
  end
  resolve_agent_and_run(function(agent)
    local ref = format_file_ref(agent.agent, abs_path, line_spec)
    herdr.send_text(agent.pane_id, ref, function(exit_code)
      if exit_code == 0 then
        vim.schedule(function()
          notify_sent(agent, ref)
        end)
      end
    end)
  end)
end

function M.send_buffer()
  local abs_path = get_absolute_path()
  if not abs_path then
    vim.notify("[herdr-send] No file", vim.log.levels.WARN)
    return
  end

  resolve_agent_and_run(function(agent)
    local ref = format_file_ref(agent.agent, abs_path)
    herdr.send_text(agent.pane_id, ref, function(exit_code)
      if exit_code == 0 then
        vim.schedule(function()
          notify_sent(agent, ref)
        end)
      end
    end)
  end)
end

function M.send_prompt()
  vim.ui.input({ prompt = "Prompt: " }, function(input)
    if not input or input == "" then
      return
    end
    resolve_agent_and_run(function(agent)
      herdr.submit_prompt(agent.pane_id, input, function(exit_code)
        if exit_code == 0 then
          vim.schedule(function()
            notify_sent(agent, "prompt")
          end)
        end
      end)
    end)
  end)
end

return M
