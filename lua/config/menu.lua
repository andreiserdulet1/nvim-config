--- The right-click menu.
---
--- Neovim already defines a PopUp menu -- Inspect, go to definition, the
--- diagnostics entries, cut/copy/paste -- and hands it to you the moment
--- `mouse` is set. What it cannot know is which of this config's actions you
--- reach for, so this adds them: the LSP three, formatting, the gitsigns hunk
--- operations, lazygit, and sending a selection to Claude.
---
--- The point is discovery. Every one of these already has a keymap, and none of
--- them are findable without knowing the keymap first; right-clicking the thing
--- you are looking at is a question anyone can ask.
---
--- Entries are given an explicit priority so they sort above Neovim's own,
--- which sit at the default 500. They are enabled and disabled on MenuPopup --
--- the same event and the same approach Neovim uses for its own entries -- so
--- an action that cannot work here is greyed out rather than failing after you
--- pick it.

local M = {}

-- Names are repeated when enabling and disabling, so they live in one place.
-- The backslashes are menu syntax: a space in a menu path has to be escaped.
local lsp_items = {
  [[PopUp.Code\ action]],
  [[PopUp.Rename\ symbol]],
  [[PopUp.Find\ usages]],
}

local git_items = {
  [[PopUp.Stage\ this\ hunk]],
  [[PopUp.Preview\ this\ hunk]],
  [[PopUp.Blame\ this\ line]],
}

local function set_enabled(items, enabled)
  local verb = enabled and "enable" or "disable"
  for _, item in ipairs(items) do
    vim.cmd(("amenu %s %s"):format(verb, item))
  end
end

function M.setup()
  -- "Find usages" is Trouble rather than a picker: a picker is gone the moment
  -- you pick something, and the question "where is this used" is usually asked
  -- while you read all of them. Trouble groups them by file and stays open,
  -- which is what WebStorm's usages panel is for. `gr` still gives the quick
  -- picker when you only want to jump.
  --
  -- "Search the project" is the text answer to the same question, for the
  -- things an LSP has no symbol for -- a string, a key in a config file, a
  -- comment. In visual mode it searches the selection, which is why that line
  -- is repeated as a vnoremenu: an anoremenu's visual variant is prefixed with
  -- <C-C>, which drops the selection before the command can read it.
  --
  -- Two lines for "Stage this hunk": the `:` in the visual one carries the
  -- '<,'> range, so only the selected lines are staged, and the anoremenu above
  -- it is not redundant -- `amenu enable` and `amenu disable` look an item up in
  -- every mode at once and fail with E329 on one that exists in only some.
  vim.cmd([[
    anoremenu 100.10 PopUp.Code\ action        <Cmd>lua vim.lsp.buf.code_action()<CR>
    vnoremenu 100.10 PopUp.Code\ action        <Cmd>lua vim.lsp.buf.code_action()<CR>
    anoremenu 100.20 PopUp.Rename\ symbol      <Cmd>lua vim.lsp.buf.rename()<CR>
    anoremenu 100.30 PopUp.Find\ usages        <Cmd>Trouble lsp_references toggle<CR>
    anoremenu 100.35 PopUp.Search\ the\ project <Cmd>Telescope grep_string<CR>
    vnoremenu 100.35 PopUp.Search\ the\ project <Cmd>Telescope grep_string<CR>
    anoremenu 100.40 PopUp.Format              <Cmd>lua require("conform").format({ async = true, lsp_format = "fallback" })<CR>
    anoremenu 100.50 PopUp.-hunks-             <Nop>
    anoremenu 100.60 PopUp.Stage\ this\ hunk   <Cmd>Gitsigns stage_hunk<CR>
    vnoremenu 100.60 PopUp.Stage\ this\ hunk   :Gitsigns stage_hunk<CR>
    anoremenu 100.70 PopUp.Preview\ this\ hunk <Cmd>Gitsigns preview_hunk_inline<CR>
    anoremenu 100.80 PopUp.Blame\ this\ line   <Cmd>lua require("gitsigns").blame_line({ full = true })<CR>
    anoremenu 100.90 PopUp.lazygit             <Cmd>LazyGit<CR>
    vnoremenu 100.95 PopUp.Send\ to\ Claude    <Cmd>ClaudeCodeSend<CR>
  ]])

  vim.api.nvim_create_autocmd("MenuPopup", {
    group = vim.api.nvim_create_augroup("config_popupmenu", { clear = true }),
    pattern = "*",
    callback = function()
      -- Nothing to rename or act on without a server attached.
      set_enabled(lsp_items, vim.lsp.get_clients({ bufnr = 0 })[1] ~= nil)
      -- gitsigns sets this when it attaches, which it only does inside a repo.
      set_enabled(git_items, vim.b.gitsigns_status_dict ~= nil)
    end,
  })
end

--- The file tree's right-click menu.
---
--- neo-tree's file operations are all bare single keys -- a, A, r, d, c, m --
--- which is the same discovery problem the PopUp menu solves for code, and a
--- context menu on a file is the one mouse gesture everybody already expects.
--- Every entry calls neo-tree's own command, so picking from the menu and
--- pressing the key do the same thing, not two similar things.
---@param state table the neo-tree state for the tree that was clicked
function M.tree(state)
  local commands = require("neo-tree.sources.filesystem.commands")

  -- Mapping <RightMouse> takes over from mousemodel=popup_setpos, and with it
  -- the cursor move that would normally happen first -- so without this the
  -- menu acts on whatever was selected before the click. getmousepos() says
  -- which line was actually clicked; neo-tree reads the node from the cursor.
  local pos = vim.fn.getmousepos()
  if pos.winid == vim.api.nvim_get_current_win() and pos.line > 0 then
    pcall(vim.api.nvim_win_set_cursor, pos.winid, { pos.line, 0 })
  end

  local node = state.tree and state.tree:get_node()
  if not node then
    return
  end

  local items = {}
  local function entry(label, run)
    items[#items + 1] = { label = label, run = run }
  end

  -- `open` toggles a directory and opens a file, which is what <cr> does here.
  entry(node.type == "directory" and "Open / close" or "Open", function()
    commands.open(state)
  end)
  if node.type ~= "directory" then
    entry("Open in a split", function() commands.open_vsplit(state) end)
  end
  entry("New file here", function() commands.add(state) end)
  entry("New folder here", function() commands.add_directory(state) end)
  entry("Rename", function() commands.rename(state) end)
  entry("Copy to...", function() commands.copy(state) end)
  entry("Move to...", function() commands.move(state) end)
  entry("Delete", function() commands.delete(state) end)
  entry("Copy the path", function()
    vim.fn.setreg("+", node.path)
    vim.notify(node.path)
  end)
  entry("Reveal in Finder", function()
    vim.ui.open(node.type == "directory" and node.path or vim.fs.dirname(node.path))
  end)
  entry("Stage", function() commands.git_add_file(state) end)
  entry("Unstage", function() commands.git_unstage_file(state) end)

  vim.ui.select(items, {
    prompt = node.name or vim.fs.basename(node.path or ""),
    format_item = function(item) return item.label end,
  }, function(choice)
    if choice then
      choice.run()
    end
  end)
end

return M
