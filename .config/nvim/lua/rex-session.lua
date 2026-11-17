-- Checkpoint the editor in its Rex pane without writing modified user files.
local M = {}
local uv = vim.uv or vim.loop
local helper = vim.fn.expand('~/.config/rex/claude-session.py')
local enabled, exiting, timer = false, false, nil
local identity = tostring(vim.fn.getpid())

local function send(data)
  data.session_id, data.cwd = identity, vim.fn.getcwd()
  local result = vim.system({ 'python3', helper, 'hook', 'nvim' },
    { stdin = vim.json.encode(data), text = true }):wait(10000)
  if result.code ~= 0 or (result.stderr or '') ~= '' then
    vim.notify('Rex checkpoint: ' .. (result.stderr or tostring(result.code)), vim.log.levels.WARN)
  end
  return result
end

function M.save()
  if not enabled or exiting or vim.env.REX_NVIM_RECOVER then return end
  local tmp, options, current = vim.fn.tempname(), vim.o.sessionoptions, vim.v.this_session
  -- Don't save terminals/jobs or plugin-local state as executable commands.
  vim.o.sessionoptions = 'buffers,curdir,folds,help,tabpages,winsize,blank'
  local ok, err = pcall(vim.cmd, 'silent mksession! ' .. vim.fn.fnameescape(tmp))
  vim.o.sessionoptions, vim.v.this_session = options, current
  if not ok then vim.notify(tostring(err), vim.log.levels.WARN); return end
  local session = table.concat(vim.fn.readfile(tmp), '\n') .. '\n'
  vim.fn.delete(tmp)
  local buffers, windows = {}, {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' and vim.bo[buf].modified then
      buffers[#buffers + 1] = {
        id = buf, name = vim.api.nvim_buf_get_name(buf),
        lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
        filetype = vim.bo[buf].filetype, endofline = vim.bo[buf].endofline,
      }
    end
  end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local wins = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_get_config(win).relative == '' then
        wins[#wins + 1] = { buffer = vim.api.nvim_win_get_buf(win), cursor = vim.api.nvim_win_get_cursor(win) }
      end
    end
    windows[#windows + 1] = wins
  end
  send({ hook_event_name = 'SessionStart', editor = { session = session, buffers = buffers, windows = windows } })
end

function M.recover()
  local path = vim.env.REX_NVIM_RECOVER
  if not path then return end
  vim.env.REX_NVIM_RECOVER = nil
  local data = vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
  local restored = {}
  for _, saved in ipairs(data.editor.buffers or {}) do
    local buf
    if saved.name == '' then
      buf = vim.api.nvim_create_buf(true, false)
    else
      buf = vim.fn.bufadd(saved.name)
      vim.fn.bufload(buf)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, saved.lines)
    vim.bo[buf].filetype, vim.bo[buf].endofline = saved.filetype, saved.endofline
    vim.bo[buf].modified = true
    restored[saved.id] = buf
  end
  for ti, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for wi, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local saved = (data.editor.windows[ti] or {})[wi]
      if saved then
        if restored[saved.buffer] then vim.api.nvim_win_set_buf(win, restored[saved.buffer]) end
        pcall(vim.api.nvim_win_set_cursor, win, saved.cursor)
      end
    end
  end
end

function M.setup()
  if not vim.env.REX_SESSION or not vim.env.REX_BLOCK or vim.env.TMUX or vim.env.CLAUDECODE then return end
  -- An editor spawned by an agent must not replace the agent's pane record.
  local result = vim.system({ 'rex', 'block', 'call', '-s', vim.env.REX_SESSION,
    '-b', vim.env.REX_BLOCK, 'process' }, { text = true }):wait(5000)
  local ok, process = pcall(vim.json.decode, result.stdout or '')
  if not ok or not process.foreground or process.foreground.name ~= 'nvim' then return end
  enabled = true
  local group = vim.api.nvim_create_augroup('RexSessionCheckpoint', { clear = true })
  timer = uv.new_timer()
  timer:start(5000, 5000, vim.schedule_wrap(M.save))
  vim.api.nvim_create_autocmd({ 'VimEnter', 'FocusLost', 'BufWritePost' }, {
    group = group, callback = function() vim.schedule(M.save) end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
    exiting = true
    timer:stop()
    timer:close()
    -- A fatal signal leaves the last periodic checkpoint active for recovery.
    if vim.v.dying == 0 then
      send({ hook_event_name = 'SessionEnd', reason = 'prompt_input_exit' })
    end
  end })
end

return M
