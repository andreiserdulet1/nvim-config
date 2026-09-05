-- A Dutch Golden Age landscape behind the code.
--
-- Neovim cannot draw a background image. Nothing in the editor can -- it paints
-- character cells, not pixels -- so the image has to come from the terminal
-- underneath, with the colourscheme made transparent so it shows through. This
-- module is the switch: it tells iTerm2 which file to put back there, and
-- clears it again on the way out, so the shell, lazygit and your tmux sessions
-- stay plain.
--
-- The images themselves are prepared by terminal/paintings/import.sh, which
-- tone-maps each painting into the narrow luminance band Graphite can afford
-- while keeping comment text at WCAG 4.5:1. Nothing here adjusts how a painting
-- looks; this file only decides which one is showing.
--
-- <Space>ub opens the picker. The choice is remembered, the same way the theme
-- is, and "No background" turns transparency off with it so you get the exact
-- opaque theme back rather than a transparent one with nothing behind it.

local M = {}

local DIR = vim.fn.stdpath("data") .. "/paintings"
local STATE = vim.fn.stdpath("data") .. "/painting"
local MANIFEST = vim.fn.stdpath("config") .. "/terminal/paintings/manifest.tsv"

-- iTerm2's proprietary OSC. The payload is a base64-encoded absolute path; an
-- empty payload means "no background image", which is how we undo ourselves.
local OSC = "\027]1337;SetBackgroundImageFile=%s\007"

-- Sentinels stored in the state file alongside real slugs.
M.RANDOM = "random"
M.NONE = "none"

-- What is on screen right now, so ColorScheme can swap to the other variant of
-- the same painting rather than jumping to an unrelated one mid-session.
M.current = nil

math.randomseed(vim.uv.hrtime() % 2147483647)

--- Whether emitting the escape code can possibly do anything.
---
--- iTerm2 is the only terminal here that understands this sequence, and a
--- headless Neovim has no UI to send bytes to at all -- guarding on both keeps
--- the module inert over SSH, in `nvim --headless`, and in CI, instead of
--- spraying escape sequences into something that will render them as text.
---@return boolean
function M.supported()
  return vim.env.TERM_PROGRAM == "iTerm.app" and #vim.api.nvim_list_uis() > 0
end

-- tmux swallows escape sequences it does not recognise, and OSC 1337 is not one
-- it knows -- unlike OSC 52, which is why Neovim's own clipboard provider gets
-- away with sending it unwrapped. Getting through means the DCS passthrough
-- form, with every inner ESC doubled, and `allow-passthrough on` set in
-- tmux.conf at the other end.
---@param seq string
local function send(seq)
  if vim.env.TMUX then
    seq = "\027Ptmux;" .. (seq:gsub("\027", "\027\027")) .. "\027\\"
  end
  vim.api.nvim_ui_send(seq)
end

--------------------------------------------------------------------------
-- What is available
--------------------------------------------------------------------------

--- Every painting with a rendered variant on disk.
---@return string[] slugs
function M.slugs()
  local out = {}
  for _, path in ipairs(vim.fn.glob(DIR .. "/*-dark.png", false, true)) do
    out[#out + 1] = (vim.fn.fnamemodify(path, ":t:r"):gsub("%-dark$", ""))
  end
  table.sort(out)
  return out
end

---@return boolean
function M.installed()
  return #M.slugs() > 0
end

-- Labels come from the manifest so the picker reads "Rembrandt · The Mill"
-- rather than "rembrandt-mill". Missing manifest is not an error: the slug is a
-- perfectly usable label, just an uglier one.
local labels
local function label_for(slug)
  if not labels then
    labels = {}
    for _, line in ipairs(vim.fn.readfile(MANIFEST)) do
      if not line:match("^#") then
        local s, _, l = line:match("^([^\t]+)\t([^\t]+)\t(.+)$")
        if s then labels[s] = l end
      end
    end
  end
  return labels[slug] or slug
end

--- The file for a slug, on whichever side of the light/dark toggle we are on.
---@param slug string
---@return string path
function M.path(slug)
  local variant = vim.o.background == "light" and "light" or "dark"
  return ("%s/%s-%s.png"):format(DIR, slug, variant)
end

--------------------------------------------------------------------------
-- The saved choice
--------------------------------------------------------------------------

--- What the picker last settled on: a slug, RANDOM, or NONE.
--- Defaults to RANDOM so a fresh install shows something without being asked.
---@return string
function M.choice()
  if vim.fn.filereadable(STATE) == 1 then
    local saved = vim.trim(vim.fn.readfile(STATE)[1] or "")
    if saved ~= "" then return saved end
  end
  return M.RANDOM
end

---@param choice string
local function save(choice)
  pcall(vim.fn.writefile, { choice }, STATE)
end

--------------------------------------------------------------------------
-- Showing and hiding
--------------------------------------------------------------------------

--- Put a painting up. Does not touch transparency or the saved choice.
---@param slug string
---@return boolean ok
function M.show(slug)
  if not M.supported() then return false end
  local path = M.path(slug)
  if vim.fn.filereadable(path) == 0 then return false end
  send(OSC:format(vim.base64.encode(path)))
  M.current = slug
  return true
end

--- Take the image down, leaving the terminal as we found it.
function M.clear()
  if not M.supported() then return end
  send(OSC:format(""))
end

--- A painting at random, avoiding an immediate repeat so the picker's "Random"
--- entry and :PaintingNext always visibly change something.
---@return string|nil slug
function M.pick()
  local slugs = M.slugs()
  if #slugs == 0 then return nil end
  if #slugs == 1 then return slugs[1] end
  local choice
  repeat
    choice = slugs[math.random(#slugs)]
  until choice ~= M.current
  return choice
end

-- Transparency is a colourscheme-build-time flag, so changing it means
-- re-applying the scheme. Re-entrancy matters: applying fires ColorScheme,
-- whose handler wants to re-show the painting, so the flag is set before the
-- apply and the handler reads the settled state rather than the old one.
---@param transparent boolean
local function set_transparency(transparent)
  if vim.g.graphite_transparent == transparent then return end
  vim.g.graphite_transparent = transparent
  local theme = require("config.theme")
  theme.apply(theme.current or vim.g.colors_name or theme.default)
end

--- Act on a choice: show a painting, show a random one, or go back to the
--- solid theme entirely.
---@param choice string
---@return boolean ok
function M.apply(choice)
  if choice == M.NONE then
    M.current = nil
    M.clear()
    set_transparency(false)
    return true
  end

  local slug = (choice == M.RANDOM) and M.pick() or choice
  if not slug or vim.fn.filereadable(M.path(slug)) == 0 then
    return false
  end

  set_transparency(true)
  return M.show(slug)
end

--- Apply a choice and remember it.
---@param choice string
function M.select(choice)
  if M.apply(choice) then
    save(choice)
  else
    vim.notify("No paintings rendered. Run terminal/paintings/import.sh", vim.log.levels.WARN)
  end
end

--------------------------------------------------------------------------
-- The picker
--------------------------------------------------------------------------

---@return table[] entries  { value = choice, label = string }
local function entries()
  local out = {
    { value = M.RANDOM, label = "Random each launch" },
    { value = M.NONE, label = "No background — solid Graphite" },
  }
  for _, slug in ipairs(M.slugs()) do
    out[#out + 1] = { value = slug, label = label_for(slug) }
  end
  return out
end

--- Pick a background, previewing each one as you move through the list.
---
--- Telescope is used when it is available, for the live preview -- seeing the
--- painting behind your actual code is the only way to judge one. It falls back
--- to vim.ui.select rather than requiring Telescope, so the picker still works
--- in a stripped-down session.
function M.menu()
  if not M.supported() then
    vim.notify("Background paintings need iTerm2", vim.log.levels.WARN)
    return
  end
  if not M.installed() then
    vim.notify("No paintings rendered. Run terminal/paintings/import.sh", vim.log.levels.WARN)
    return
  end

  local items = entries()
  local restore = M.choice()

  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.ui.select(items, {
      prompt = "Background",
      format_item = function(item) return item.label end,
    }, function(item)
      if item then M.select(item.value) end
    end)
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_set = require("telescope.actions.set")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Background",
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        return { value = item.value, display = item.label, ordinal = item.label }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      -- Preview on move. Deliberately does NOT save: moving the cursor over an
      -- entry should show it, not commit to it.
      action_set.shift_selection:enhance({
        post = function()
          local entry = action_state.get_selected_entry()
          if entry then M.apply(entry.value) end
        end,
      })

      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then M.select(entry.value) end
      end)

      -- Escaping puts back whatever was showing before the picker opened,
      -- so browsing costs nothing.
      actions.close:enhance({ post = function() M.apply(restore) end })
      return true
    end,
  }):find()
end

--------------------------------------------------------------------------

function M.setup()
  vim.api.nvim_create_user_command("Painting", M.menu, {
    desc = "Pick the background painting",
  })

  vim.api.nvim_create_user_command("PaintingNext", function()
    local slug = M.pick()
    if slug then M.select(slug) else
      vim.notify("No paintings rendered. Run terminal/paintings/import.sh", vim.log.levels.WARN)
    end
  end, { desc = "Show a different painting behind the editor" })

  vim.api.nvim_create_user_command("PaintingOff", function()
    M.select(M.NONE)
  end, { desc = "Turn the background painting off" })

  if not (M.supported() and M.installed()) then return end

  local group = vim.api.nvim_create_augroup("painting", { clear = true })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function() M.apply(M.choice()) end,
  })

  -- Both, deliberately. Ctrl-Z would otherwise leave the painting sitting behind
  -- the shell you dropped into, which is precisely what "only inside Neovim"
  -- was meant to avoid.
  vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
    group = group,
    callback = function() M.clear() end,
  })

  vim.api.nvim_create_autocmd("VimResume", {
    group = group,
    callback = function()
      if M.current then M.show(M.current) end
    end,
  })

  -- <leader>ut flips light/dark. Re-show the same painting so it follows the
  -- theme across rather than leaving a dark-mapped image behind the paper
  -- variant, where it would read as a grey rectangle.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      if M.current then M.show(M.current) end
    end,
  })
end

return M
