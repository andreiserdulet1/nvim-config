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
  { cmd = "jira",        why = "the whole <leader>j Jira layer",                      fix = "brew install ankitpokhrel/jira-cli/jira-cli", required = false },
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
  if vim.fn.has("nvim-0.12") == 1 then
    health.ok("Neovim " .. version .. " (0.12+ required)")
  else
    health.error("Neovim " .. version .. " is too old — this config uses vim.lsp.config "
      .. "and vim.lsp.document_color, and assumes vim.diagnostic.disable is gone",
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

  ---------------------------------------------------------------------------
  health.start("Jira")
  ---------------------------------------------------------------------------
  -- Four independent parts, each of which fails as an unhelpful CLI error if
  -- you only find out about it at <leader>js. Checked in dependency order and
  -- stopped at the first break, so the report names one thing to fix.
  local jira = require("config.jira")

  if vim.fn.executable("jira") == 0 then
    health.info("jira-cli not installed — the <leader>j keys are inert, "
      .. "everything else works normally.",
      { "brew bundle --file=~/.config/nvim/Brewfile" })
  elseif vim.fn.filereadable(jira.CONFIG) == 0 then
    health.warn("jira-cli is installed but not configured",
      { "Run: jira init",
        "Cloud · https://<your-site>.atlassian.net · your login · pick a project and board",
        "It writes " .. vim.fn.fnamemodify(jira.CONFIG, ":~") .. ", outside this repo." })
  else
    local account = jira.login()
    if not account then
      health.warn("No `login:` line in " .. vim.fn.fnamemodify(jira.CONFIG, ":~"),
        { "Re-run: jira init" })
    else
      health.ok("Configured as " .. account)

      -- Presence only. The value is never read into the report, and never
      -- printed anywhere: :checkhealth output gets pasted into tickets.
      local found = vim.system(
        { "security", "find-generic-password", "-s", jira.SERVICE, "-a", account },
        { text = true }
      ):wait()

      if found.code ~= 0 then
        health.error("No API token in the Keychain for " .. account,
          { "security add-generic-password -s " .. jira.SERVICE
            .. " -a " .. account .. " -U -w",
            "It prompts for the token without echoing it.",
            "Create one at https://id.atlassian.com/manage-profile/security/api-tokens" })
      else
        health.ok("API token present in the Keychain (service: " .. jira.SERVICE .. ")")

        local issues, err = jira.sprint_issues()
        if issues then
          health.ok(("Reached Jira — %d issue(s) in the current sprint"):format(#issues))
        else
          health.error("jira-cli could not read the current sprint",
            { vim.split(err or "", "\n")[1] or "unknown error",
              "Check the token is still valid, and that the configured board has an active sprint." })
        end
      end
    end
  end

  ---------------------------------------------------------------------------
  health.start("Background paintings")
  ---------------------------------------------------------------------------
  -- This one has four independent parts and fails silently when any is missing,
  -- which is the worst possible combination -- you get a plain editor and no
  -- clue which link in the chain broke. So report on each separately.
  local painting = require("config.painting")

  -- Test the terminal directly rather than asking painting.supported(), which
  -- also requires an attached UI -- otherwise a headless :checkhealth reports
  -- "you need iTerm2" at someone who is already running iTerm2.
  if vim.env.TERM_PROGRAM == "iTerm.app" then
    health.ok("iTerm2 — it can draw a background image behind the editor")
  else
    health.info("Backgrounds need iTerm2; nothing is emitted in "
      .. (vim.env.TERM_PROGRAM or "this terminal")
      .. ". Everything else works exactly as normal.")
  end

  local slugs = painting.slugs()
  if #slugs > 0 then
    health.ok(("%d paintings rendered"):format(#slugs))
  else
    health.warn("No paintings rendered",
      { "Run ~/.config/nvim/terminal/paintings/import.sh",
        "Until then the theme stays opaque, which is a working editor." })
  end

  local choice = painting.choice()
  if choice == painting.NONE then
    health.info("Set to 'No background' — the theme is solid. <Space>ub to change it.")
  elseif choice == painting.RANDOM then
    health.ok("Set to a random painting each launch")
  elseif vim.tbl_contains(slugs, choice) then
    health.ok("Set to " .. choice)
  else
    health.warn(("Set to '%s', which is not rendered"):format(choice),
      { "Pick another with <Space>ub, or re-run import.sh." })
  end

  if vim.fn.executable("magick") == 1 then
    health.ok("magick — import.sh can render the paintings")
  else
    health.info("ImageMagick is missing. It is only needed to re-render the "
      .. "paintings, so an already-rendered set keeps working: brew install imagemagick")
  end

  -- tmux drops the escape sequence unless passthrough is on, which shows up as
  -- "works in a plain shell, does nothing under `dev`".
  if vim.env.TMUX and vim.fn.executable("tmux") == 1 then
    local passthrough = vim.trim(vim.fn.system({ "tmux", "show", "-gv", "allow-passthrough" }))
    if passthrough == "on" then
      health.ok("tmux allow-passthrough on — the escape sequence reaches iTerm2")
    else
      health.warn("tmux allow-passthrough is " .. (passthrough == "" and "unset" or passthrough),
        { "terminal/tmux.conf sets it; this session predates that.",
          "Fix with: tmux source-file ~/.tmux.conf" })
    end
  end
end

return M
