--- The right-click menu.
---
--- Neovim already defines a PopUp menu -- Inspect, go to definition, the
--- diagnostics entries, cut/copy/paste -- and hands it to you the moment
--- `mouse` is set. What it cannot know is which of this config's actions you
--- reach for, so this adds them: the LSP three, formatting, the gitsigns hunk
--- operations, lazygit, asking Claude about the code under the pointer,
--- testing the component, the dev servers, and the command palette.
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

-- Only offered on an Angular component's files.
local component_items = {
  [[PopUp.Go\ to\ template]],
  [[PopUp.Go\ to\ styles]],
  [[PopUp.Go\ to\ spec]],
  [[PopUp.Go\ to\ class]],
  [[PopUp.Test\ this\ component]],
}

-- Only offered in a spec.
local test_items = {
  [[PopUp.Run\ this\ test]],
  [[PopUp.Run\ this\ spec]],
  [[PopUp.Claude:\ fix\ failing\ test]],
}

-- Only offered when there is a diagnostic on the clicked line.
local diag_items = {
  [[PopUp.Claude:\ fix\ this]],
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
    anoremenu 100.35 PopUp.Search\ the\ project <Cmd>lua Snacks.picker.grep_word()<CR>
    vnoremenu 100.35 PopUp.Search\ the\ project <Cmd>lua Snacks.picker.grep_word()<CR>
    anoremenu 100.40 PopUp.Format              <Cmd>lua require("conform").format({ async = true, lsp_format = "fallback" })<CR>
    anoremenu 100.50 PopUp.-hunks-             <Nop>
    anoremenu 100.60 PopUp.Stage\ this\ hunk   <Cmd>Gitsigns stage_hunk<CR>
    vnoremenu 100.60 PopUp.Stage\ this\ hunk   :Gitsigns stage_hunk<CR>
    anoremenu 100.70 PopUp.Preview\ this\ hunk <Cmd>Gitsigns preview_hunk_inline<CR>
    anoremenu 100.80 PopUp.Blame\ this\ line   <Cmd>lua require("gitsigns").blame_line({ full = true })<CR>
    anoremenu 100.90 PopUp.lazygit             <Cmd>LazyGit<CR>
    anoremenu 100.05 PopUp.Copy…               <Cmd>lua require("config.copy").menu()<CR>
    vnoremenu 100.05 PopUp.Copy…               <Cmd>lua require("config.copy").menu()<CR>
    anoremenu 100.06 PopUp.Paste\ from\ history… <Cmd>lua require("config.copy").history()<CR>
    anoremenu 100.91 PopUp.-claude-            <Nop>
    anoremenu 100.92 PopUp.Ask\ Claude\ about\ this <Cmd>lua require("config.claude").ask()<CR>
    vnoremenu 100.92 PopUp.Ask\ Claude\ about\ this <Cmd>lua require("config.claude").ask()<CR>
    anoremenu 100.93 PopUp.Claude:\ fix\ this  <Cmd>lua require("config.claude").fix()<CR>
    anoremenu 100.94 PopUp.Claude:\ explain    <Cmd>lua require("config.claude").explain()<CR>
    vnoremenu 100.94 PopUp.Claude:\ explain    <Cmd>lua require("config.claude").explain()<CR>
    vnoremenu 100.95 PopUp.Send\ to\ Claude    <Cmd>ClaudeCodeSend<CR>
    anoremenu 100.95 PopUp.Git…               <Cmd>lua require("config.vcs").menu()<CR>
    anoremenu 100.96 PopUp.-run-               <Nop>
    anoremenu 100.97 PopUp.Run\ this\ test     <Cmd>lua require("config.tests").run_nearest()<CR>
    anoremenu 100.97 PopUp.Run\ this\ spec     <Cmd>lua require("config.tests").run_file()<CR>
    anoremenu 100.97 PopUp.Claude:\ fix\ failing\ test <Cmd>lua require("config.tests").send_failure()<CR>
    anoremenu 100.101 PopUp.Go\ to\ template   <Cmd>lua require("config.component").open("html")<CR>
    anoremenu 100.102 PopUp.Go\ to\ styles     <Cmd>lua require("config.component").open("style")<CR>
    anoremenu 100.103 PopUp.Go\ to\ spec       <Cmd>lua require("config.component").open("spec")<CR>
    anoremenu 100.104 PopUp.Go\ to\ class      <Cmd>lua require("config.component").open("ts")<CR>
    anoremenu 100.97 PopUp.Test\ this\ component <Cmd>lua require("config.scripts").test_file()<CR>
    anoremenu 100.98 PopUp.Dev\ servers…       <Cmd>lua require("config.services").menu()<CR>
    anoremenu 100.105 PopUp.Related\ files…    <Cmd>lua require("config.related").pick()<CR>
    anoremenu 100.110 PopUp.-edit-              <Nop>
    nnoremenu 100.111 PopUp.Toggle\ comment     <Cmd>normal gcc<CR>
    vnoremenu 100.111 PopUp.Toggle\ comment     <Cmd>normal gc<CR>
    vnoremenu 100.112 PopUp.Format\ selection   <Cmd>lua require("conform").format({ async = true, lsp_format = "fallback" })<CR>
    vnoremenu 100.113 PopUp.Sort\ lines         :sort<CR>
    anoremenu 100.114 PopUp.Undo\ history       <Cmd>UndotreeToggle<CR>
    anoremenu 100.115 PopUp.Compare\ with…     <Cmd>lua require("config.compare").menu()<CR>
    vnoremenu 100.115 PopUp.Compare\ with\ clipboard <Cmd>lua require("config.compare").with_clipboard()<CR>
    anoremenu 100.116 PopUp.Open\ on\ GitHub     <Cmd>lua require("config.copy").open_github()<CR>
    vnoremenu 100.116 PopUp.Open\ on\ GitHub     <Cmd>lua require("config.copy").open_github()<CR>
    anoremenu 100.120 PopUp.All\ commands…      <Cmd>lua require("config.palette").open()<CR>
  ]])

  vim.api.nvim_create_autocmd("MenuPopup", {
    group = vim.api.nvim_create_augroup("config_popupmenu", { clear = true }),
    pattern = "*",
    callback = function()
      -- Nothing to rename or act on without a server attached.
      set_enabled(lsp_items, vim.lsp.get_clients({ bufnr = 0 })[1] ~= nil)
      set_enabled(diag_items, #vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 }) > 0)
      set_enabled(test_items, vim.api.nvim_buf_get_name(0):match("%.spec%.ts$") ~= nil)
      set_enabled(component_items, vim.api.nvim_buf_get_name(0):match("%.component%.[%w.]+$") ~= nil)
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
  local dir = node.type == "directory" and node.path or vim.fs.dirname(node.path)
  local is_ts = node.type ~= "directory" and node.path:match("%.ts$") ~= nil
  if is_ts or (node.type ~= "directory" and node.path:match("%.html$")) then
    entry("Test this component", function() require("config.scripts").test_file(node.path) end)
  end
  entry("Search in " .. (node.type == "directory" and "this folder" or "this file's folder"), function()
    Snacks.picker.grep({ dirs = { dir } })
  end)
  entry("Terminal here", function()
    require("toggleterm.terminal").Terminal
      :new({ dir = dir, direction = "float", hidden = true, display_name = "shell @ " .. vim.fs.basename(dir) })
      :toggle()
  end)
  if vim.fs.find("angular.json", { upward = true, path = dir, type = "file" })[1] then
    entry("ng generate here…", function() require("config.angular").generate_pick(dir) end)
  end
  entry("Ask Claude about this", function()
    local ref = "@" .. vim.fn.fnamemodify(node.path, ":.")
    vim.ui.input({ prompt = "Ask Claude about " .. ref .. ": " }, function(q)
      if q and vim.trim(q) ~= "" then require("config.claude").ask_with(ref .. " " .. q) end
    end)
  end)
  entry("Add to Claude's context", function()
    vim.cmd("ClaudeCodeAdd " .. vim.fn.fnameescape(node.path))
  end)
  entry(node.type == "directory" and "Compare this folder with another repo…" or "Compare with…", function()
    require("config.compare").pick_other(node.path)
  end)
  entry("Copy relative path", function() require("config.copy").copy_relative(node.path) end)
  entry("Copy absolute path", function()
    vim.fn.setreg("+", node.path)
    vim.notify("Copied " .. node.path)
  end)
  entry("Copy GitHub link", function()
    local url = require("config.copy").github_url(node.path)
    if url then vim.fn.setreg("+", url) vim.notify("Copied " .. url) end
  end)
  entry("Open on GitHub", function()
    local url = require("config.copy").github_url(node.path)
    if url then vim.ui.open(url) end
  end)
  entry("Reveal in Finder", function() vim.ui.open(dir) end)
  if node.type ~= "directory" then
    entry("Git: rollback…", function() require("config.vcs").rollback(node.path) end)
    entry("Git: history", function() vim.cmd("DiffviewFileHistory " .. vim.fn.fnameescape(node.path)) end)
  end
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

--- A buffer tab's right-click menu (bufferline). Middle-click still closes.
---@param bufnr integer
function M.buffer(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local name = path ~= "" and vim.fs.basename(path) or "[No Name]"
  local items = {
    { "Close", function() Snacks.bufdelete(bufnr) end },
    { "Close all others", function()
        vim.api.nvim_set_current_buf(bufnr)
        Snacks.bufdelete.other()
      end },
    { "Close everything to the right", function() vim.cmd("BufferLineCloseRight") end },
    { "Pin / unpin", function()
        vim.api.nvim_set_current_buf(bufnr)
        vim.cmd("BufferLineTogglePin")
      end },
    { "Open in a split", function() vim.cmd("vsplit | buffer " .. bufnr) end },
  }
  if path ~= "" then
    vim.list_extend(items, {
      { "Reveal in the file tree", function() vim.cmd("Neotree reveal_file=" .. vim.fn.fnameescape(path)) end },
      { "Copy relative path", function() require("config.copy").copy_relative(path) end },
      { "Copy GitHub link", function()
          local url = require("config.copy").github_url(path)
          if url then vim.fn.setreg("+", url) vim.notify("Copied " .. url) end
        end },
      { "Open on GitHub", function()
          local url = require("config.copy").github_url(path)
          if url then vim.ui.open(url) end
        end },
      { "Add to Claude's context", function() vim.cmd("ClaudeCodeAdd " .. vim.fn.fnameescape(path)) end },
      { "File history", function() vim.cmd("DiffviewFileHistory " .. vim.fn.fnameescape(path)) end },
      { "Compare with…", function() require("config.compare").menu(path) end },
    })
  end
  vim.ui.select(items, {
    prompt = name,
    format_item = function(i) return i[1] end,
  }, function(i) if i then i[2]() end end)
end

--- A terminal's right-click menu. Terminals take the mouse away from the
--- PopUp menu, so this is mapped on each terminal buffer (config/layout.lua).
function M.terminal()
  local buf = vim.api.nvim_get_current_buf()
  local chan = vim.bo[buf].channel
  local items = {
    { "Paste", function()
        local text = vim.fn.getreg("+")
        if chan and chan > 0 and text ~= "" then
          vim.fn.chansend(chan, "\27[200~" .. text .. "\27[201~")
        end
      end },
    { "Copy the last 80 lines", function()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        while #lines > 0 and vim.trim(lines[#lines]) == "" do table.remove(lines) end
        vim.fn.setreg("+", table.concat(vim.list_slice(lines, math.max(1, #lines - 79)), "\n"))
        vim.notify("Copied the terminal's last lines")
      end },
    { "Send the last 80 lines to Claude", function()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        while #lines > 0 and vim.trim(lines[#lines]) == "" do table.remove(lines) end
        require("config.claude").ask_with("This is terminal output. Explain what went wrong and fix it.\n```\n"
          .. table.concat(vim.list_slice(lines, math.max(1, #lines - 79)), "\n") .. "\n```")
      end },
    { "Scroll / select (normal mode)", function() vim.cmd("stopinsert") end },
    { "Move: float", function() require("config.layout").move(0, "float") end },
    { "Move: bottom", function() require("config.layout").move(0, "bottom") end },
    { "Move: right", function() require("config.layout").move(0, "right") end },
    { "Hide", function() require("config.layout").hide(vim.api.nvim_get_current_win()) end },
  }
  vim.ui.select(items, {
    prompt = "Terminal",
    format_item = function(i) return i[1] end,
  }, function(i) if i then i[2]() end end)
end

return M
