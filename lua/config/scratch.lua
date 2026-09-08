-- Read-only output in a scratch buffer.
--
-- Two modules want the same window: a workflow run's logs, and a Jira issue.
-- Both want the text searchable and yankable rather than trapped in a
-- notification, both want `q` to close it, and both want a name in the buffer
-- list saying where it came from.
--
-- The only things that actually differ are the URL scheme, the filetype and
-- whether long lines wrap, so those are the options.

local M = {}

--- Open `text` in a read-only scratch buffer.
---@param name string      shown as "<scheme>://<name>" in the buffer list
---@param text string
---@param opts table|nil   { scheme = "gh", filetype = "log", wrap = false,
---                          split = "botright vsplit" }
---@return integer buf
function M.open(name, text, opts)
  opts = opts or {}

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = opts.filetype or "log"
  vim.bo[buf].bufhidden = "wipe"

  vim.cmd(opts.split or "botright vsplit")
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.wrap = opts.wrap == true

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })

  -- pcall: two of these open in the same session collide on the name, and a
  -- duplicate-name error is not worth losing the buffer over.
  pcall(vim.api.nvim_buf_set_name, buf, (opts.scheme or "scratch") .. "://" .. name)

  return buf
end

return M
