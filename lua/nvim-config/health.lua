-- :checkhealth nvim-config
--
-- Neovim's own :checkhealth covers plugins and language servers. It does not
-- cover the command-line tools this config drives, and those fail quietly: no
-- delta means lazygit diffs just look worse, no terraform means hover comes back
-- empty. This reports on them, says what each one is for, and gives the fix.

local M = {}

local health = vim.health

-- Tools installed by the Brewfile and expected on $PATH.
local PATH_TOOLS = {
  { cmd = "rg",          why = "Telescope live grep, and grug-far search & replace", fix = "brew install ripgrep",         required = true },
  { cmd = "fd",          why = "Telescope file finding",                             fix = "brew install fd",              required = true },
  { cmd = "delta",       why = "side-by-side diffs inside lazygit",                   fix = "brew install git-delta",       required = true },
  { cmd = "tree-sitter", why = "compiling treesitter parsers (the main branch needs it)", fix = "brew install tree-sitter-cli", required = true },
  { cmd = "lazygit",     why = "<leader>gg, the main git interface",                  fix = "brew install lazygit",         required = true },
  { cmd = "gh",          why = "pull requests (<leader>p) and Actions (<leader>A)",   fix = "brew install gh",              required = true },
  { cmd = "git",         why = "everything git-related",                              fix = "xcode-select --install",       required = true },
  { cmd = "terraform",   why = "terraform-ls hover and fmt on save",                  fix = "brew install hashicorp/tap/terraform", required = false },
  { cmd = "node",        why = "the Angular language server and every JS tool",       fix = "brew install node",            required = false },
  { cmd = "yarn",        why = "running project scripts (<leader>nr, <leader>nt)",    fix = "npm install -g yarn",          required = false },
}

-- These live in Mason's bin directory, which is deliberately NOT on $PATH.
-- Checking them with executable() alone would report them missing on a
-- perfectly healthy machine, which is worse than not checking at all.
local MASON_TOOLS = {
  { cmd = "ngserver",                      why = "Angular templates and inline templates" },
  { cmd = "vtsls",                         why = "TypeScript" },
  { cmd = "vscode-eslint-language-server", why = "ESLint diagnostics as you type" },
  { cmd = "terraform-ls",                  why = "Terraform completion and hover" },
  { cmd = "tflint",                        why = "Terraform linting" },
  { cmd = "js-debug-adapter",              why = "debugging Angular in Chrome (<leader>d)" },
  { cmd = "shfmt",                         why = "shell script formatting" },
}

local function mason_bin()
  return vim.fn.stdpath("data") .. "/mason/bin"
end

function M.check()
  ---------------------------------------------------------------------------
  health.start("Neovim itself")
  ---------------------------------------------------------------------------
  local v = vim.version()
  local version = ("%d.%d.%d"):format(v.major, v.minor, v.patch)
  if vim.fn.has("nvim-0.11") == 1 then
    health.ok("Neovim " .. version .. " (0.11+ required for vim.lsp.config)")
  else
    health.error("Neovim " .. version .. " is too old — this config uses vim.lsp.config",
      { "brew upgrade neovim" })
  end

  ---------------------------------------------------------------------------
  health.start("Command-line tools (Brewfile)")
  ---------------------------------------------------------------------------
  local missing_required = 0
  for _, t in ipairs(PATH_TOOLS) do
    if vim.fn.executable(t.cmd) == 1 then
      health.ok(("%-12s %s"):format(t.cmd, t.why))
    elseif t.required then
      missing_required = missing_required + 1
      health.error(("%-12s missing — needed for %s"):format(t.cmd, t.why), { t.fix })
    else
      health.warn(("%-12s missing — %s will not work"):format(t.cmd, t.why), { t.fix })
    end
  end
  if missing_required == 0 then
    health.info("Everything the Brewfile installs is present.")
  else
    health.info("Install everything at once: brew bundle --file=~/.config/nvim/Brewfile")
  end

  ---------------------------------------------------------------------------
  health.start("Mason-managed tools")
  ---------------------------------------------------------------------------
  local bin = mason_bin()
  if vim.fn.isdirectory(bin) == 0 then
    health.error("Mason has not installed anything yet at " .. bin,
      { "Open Neovim and wait, or run :MasonToolsInstall" })
  else
    local missing = {}
    for _, t in ipairs(MASON_TOOLS) do
      if vim.fn.executable(bin .. "/" .. t.cmd) == 1 then
        health.ok(("%-32s %s"):format(t.cmd, t.why))
      else
        table.insert(missing, t.cmd)
        health.warn(("%-32s missing — %s"):format(t.cmd, t.why))
      end
    end
    if #missing > 0 then
      health.info("Install with :MasonToolsInstall (these are not brew packages)")
    end
  end

  ---------------------------------------------------------------------------
  health.start("Angular")
  ---------------------------------------------------------------------------
  -- Some repos here don't ship @angular/language-service, so a pinned copy acts
  -- as the last probe location. Project-local always wins over it.
  local fallback = vim.fn.stdpath("data") .. "/angular-fallback/node_modules/@angular/language-service"
  if vim.fn.isdirectory(fallback) == 1 then
    local pkg = fallback .. "/package.json"
    local ver = "?"
    local ok, lines = pcall(vim.fn.readfile, pkg)
    if ok then
      local decoded = vim.json.decode(table.concat(lines, "\n"), { luanil = { object = true } })
      ver = (type(decoded) == "table" and decoded.version) or "?"
    end
    health.ok("language-service fallback present (" .. ver .. ") for repos that don't ship one")
  else
    health.warn("No @angular/language-service fallback installed",
      { "Repos that don't ship one will have weaker template support.",
        "See the README section on Angular." })
  end

  ---------------------------------------------------------------------------
  health.start("Terminal")
  ---------------------------------------------------------------------------
  if vim.env.TERM_PROGRAM then
    health.info("TERM_PROGRAM = " .. vim.env.TERM_PROGRAM)
  end
  if vim.o.termguicolors then
    health.ok("termguicolors on — the theme will render correctly")
  else
    health.warn("termguicolors is off; colours will look wrong")
  end
  -- snacks.image only speaks the Kitty graphics protocol.
  local term = (vim.env.TERM_PROGRAM or ""):lower()
  if term:match("ghostty") or term:match("wezterm") or vim.env.KITTY_WINDOW_ID then
    health.ok("This terminal can render images inside the buffer")
  else
    health.info("Images can't render in-buffer here (needs kitty, ghostty or wezterm). "
      .. "Use macOS Quick Look instead.")
  end
end

return M
