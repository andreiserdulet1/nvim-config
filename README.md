# Neovim IDE — Angular / TypeScript + Terraform

A hand-rolled Neovim config, ~30 plugins, built for front-end work on Angular
repos (with Terraform on the side). It works the same in every repo under
`~/projects`: start the app and its wiremock in one key, or run it inside
shell-ui on any branch; drive Claude from the code you're looking at; and do
most of it with the mouse if you prefer.

Start it with `v` (the alias already in your `~/.zshrc`) or `nvim`.
Press `<Space>?` inside Neovim at any time for the keymap cheatsheet.

**Web guide:** https://claude.ai/code/artifact/fa81e147-7724-4e98-9a71-0a9f36c71547

---

## Setting this up on a new machine

```
git clone git@github.com:andreiserdulet1/nvim-config.git ~/.config/nvim
brew bundle --file=~/.config/nvim/Brewfile
~/.config/nvim/terminal/install.sh
nvim
```

`brew bundle` installs **MesloLG Nerd Font**, which every icon in this config
depends on — but Homebrew cannot select it for you. Set your terminal's font to
*MesloLGL Nerd Font Mono* before the first launch, or the dashboard, the
statusline separators, the git gutter and the diagnostic signs will all render
as question marks. `:checkhealth nvim-config` prints a glyph probe to confirm.

`install.sh` symlinks the tmux config, the starship prompt, the lazygit config
and the global gitignore into place. It backs up anything already there and
**refuses** to overwrite a file you have edited locally, showing the diff instead.
It never touches `~/.zshrc` — that file has machine-specific things in it, so the
lines it needs are recorded in `terminal/zshrc.snippet` and only checked for.

First launch installs 44 plugins and downloads language servers; give it a couple
of minutes and watch the bottom of the screen. Then run **`:checkhealth nvim-config`** —
it lists every command-line tool this config drives, what depends on each one, and
the exact command to install anything missing.

Jira needs three more commands and a Keychain entry, which are deliberately not
automated — see [Jira](#jira).

Language servers and linters are **not** in the Brewfile; Mason
installs those. Note that `brew bundle check` also reports merely *outdated*
formulae as unsatisfied, so don't read that as broken.

## Your first fifteen minutes

If you've never used vim, spend thirty minutes on `vimtutor` first — run it in a
terminal, not in here. Nothing below will make sense without it.

Then, in order:

1. **Press `<C-p>` (or click ☰ in the statusline).** Every command in this config,
   searchable, with its key shown beside it. When you don't know how, start here.
2. **`<Space><Space>`** to open a file, **`<Space>fg`** to search across the project.
   Those two cover most navigation.
3. **`<Space>ns`** starts the project you're in (`yarn start` + `yarn wiremock`);
   **`<Space>nS`** runs it inside shell-ui on a branch you pick. `<Space>nx` stops it.
4. **`<Space>ac`** opens Claude; **`<Space>aq`** asks it about the line you're on.
5. **`gd`** jumps to a definition, **`<C-o>`** comes back.
6. **`<Space>gg`** for git, **`<Space>?`** for the cheatsheet.

Pressing `<Space>` and waiting shows every key that can follow, so you never
need to memorise this file. Right-click anything for what you can do with it.

Two things that will save you: **`<Space>uu`** shows your undo history as a tree, so
nothing is ever really lost, and reopening a file puts you back where you were.

There used to be two teaching plugins here — hardtime nagging you for holding `j`,
and precognition drawing motion hints. Both were removed once they had done their
job; if you want them back they are two entries in `lua/plugins/editor.lua`.

---

## 1. Layout

```
~/.config/nvim/
├── init.lua                 leader key + bootstrap
├── colors/graphite.lua      the colourscheme (palette in lua/scheme/)
├── lua/config/
│   ├── options.lua          editor behaviour, diagnostics, filetypes
│   ├── keymaps.lua          keymaps that don't belong to a plugin
│   ├── services.lua         dev servers: start / shell-ui / stop / status
│   ├── claude.lua           Claude position, conversations, "ask about this"
│   ├── layout.lua           terminal positions + their clickable winbar
│   ├── palette.lua          <C-p>: every command in one list
│   ├── menu.lua             the right-click menus
│   ├── scripts.lua          package.json scripts and tests
│   ├── actions.lua          GitHub Actions + PRs via gh
│   ├── jira.lua             sprint, board, transitions, comments
│   ├── projects.lua         project switcher over ~/projects
│   └── cheatsheet.lua       the <Space>? popup
└── lua/plugins/
    ├── ui.lua               statusline (and its buttons), buffer tabs, dashboard
    ├── editor.lua           snacks.picker, neo-tree, which-key, flash, treesitter
    ├── lsp.lua              mason, language servers, completion
    ├── lint.lua             prettier/terraform fmt + tflint
    ├── git.lua              lazygit, gitsigns, diffview
    └── term.lua             claude + terminals
```

It is a git repo. If a change breaks something, `git diff` and `git checkout` it.

---

## 2. The ten keys that matter

Learn these first; everything else is discoverable by pressing `<Space>` and waiting.

| Key | Does |
|---|---|
| `<Space><Space>` | Find a file |
| `<Space>fg` | Search text across the project |
| `<Space>e` | Toggle the file tree |
| `<Space>gg` | **lazygit** |
| `gd` | Jump to definition |
| `gr` | Find every reference |
| `K` | Show documentation |
| `<Space>ca` | Code actions (auto-import, quick fix) |
| `<Space>ns` | Start this project (app + wiremock) |
| `<Space>ac` | Claude |
| `<C-p>` | Every command, searchable |
| `<Space>?` | The full cheatsheet |

### With the mouse

Everything has a mouse route, and the statusline is the control panel:

| Click | Does |
|---|---|
| `▶ Run` / the service dots | dev servers menu — right-click stops them all |
| `✦ Claude` | show / hide Claude — right-click to move it |
| `⚙ CI ✓` | this branch's workflow runs (shown when the repo has workflows) |
| `☰` | every command, searchable |
| the branch / diagnostics / diff | lazygit / Trouble / diffview |

**Right-click** in code for *Copy…*, code actions, rename, usages, hunks, *Ask
Claude*, *Claude: fix this* (when the line has a diagnostic), *Test this
component*, *Go to template / styles / spec*, toggle comment, *Compare with…* and
*Open on GitHub*. On a selection you also get format, sort and compare with the
clipboard.

Right-click a **file or folder in the tree** to create, rename, delete, stage, run
its spec, search inside it, open a terminal there, `ng generate` into it, ask
Claude about it, compare it with another repo, or copy its path or GitHub link.
Right-click a **buffer tab** to close it / the others / everything to its right,
pin it, reveal it, copy its path or link, or see its history (middle-click still
closes). Right-click a **terminal** to paste, copy or send its output to Claude,
move or hide it. Splits resize by dragging, and the dashboard runs an entry on
double-click.

### Copying

**With the mouse:** drag to select and it's on the clipboard — like a terminal,
and the selection stays so you can still act on it. **Cmd+V** pastes, in text and
in terminals. Right-click has *Copy*, *Paste*, *Copy…* and *Paste from history*.
(iTerm2 hands mouse drags to Neovim, which is why Cmd+C has nothing to copy —
select-to-copy is the replacement. `<Space>uy` turns it off.)

**With the keyboard:**

Right-click → *Copy…*, `<Space>yy`, or click the file name in the statusline:

| Key | Copies |
|---|---|
| `<Space>yg` | a **GitHub permalink** to the line / selection (pinned to the commit when it's pushed) |
| `<Space>yr` | `src/app/x.component.ts:12-20` |
| `<Space>ym` | the selection as a fenced Markdown block, path on top — for Jira, Slack, PRs |
| `<Space>yp` | the relative path |
| `<Space>yi` | `import { Symbol } from '…'`, relative to the file you came from |

The menu also has the absolute path, file name, the diagnostic on the line, the
Jira key from your branch and the branch name. `<Space>fy` is **clipboard history**
for the session: `<CR>` pastes an earlier copy, `<C-y>` puts it back on the
clipboard.

### Comparing, and two repos at once

Every comparison opens in its own tab, labelled on top, with ✕ to close it
(`<Space>Dq`). `]c` / `[c` walk the changes; `do` takes the other side's.

| Key | Compares |
|---|---|
| `<Space>Dr` | this file with the **same path in another repo** — migrations |
| `<Space>Db` | this file with another branch |
| `<Space>Do` / `<Space>Dc` | with another open file / with the clipboard |
| `<Space>DF` | **two repos or folders, file by file**: every changed, added and removed file — and moved ones, matched up (`R` moved unchanged, `R~` moved and edited) — with a diff preview; `<CR>` opens one, `<Space>fc` returns to the list |

To **work in two repos at once**, `<Space>Dt` opens another repo in a new tab
with its own working directory — the pickers, grep, the tree, terminals and
`<Space>ns` all act on that repo while you're in the tab (`gt`/`gT`, or click the
tab numbers top-right, to switch). `<Space>Ds` does the same in a split beside
your current file.

### Themes

One theme, **Graphite** — warm neutral greys with amber and sage — in dark and
light. `<Space>ut` flips between them and the choice is remembered.

It **ships in this repo** — `colors/graphite.lua` with its palette in
`lua/scheme/palettes/` — and is not a plugin, because `~/.config/nvim` is already
on the runtime path. There is nothing to install and nothing to load eagerly to
avoid a flash of the wrong colours; `init.lua` simply applies the saved one before
lazy.nvim starts.

The highlight groups live in one engine, `lua/scheme/init.lua`, and the palette
supplies colours by **role**, not by name — so adding another theme later means
writing one palette file and a two-line `colors/` shim.

The hue assignment is the actual design decision, not an afterthought:

| Colour | Carries |
|---|---|
| amber | functions and methods — what you scan a file for |
| clay | keywords and control flow |
| sage | strings |
| slate | numbers, booleans, constants |
| ochre | types, classes, interfaces |
| plain text | variables and properties, left uncoloured to cut noise |

Operators and punctuation get dim text rather than a hue of their own.

**Every text colour was set against a measured contrast ratio**, and the ratio is
recorded next to it in the palette file. Graphite's first draft failed on comments
— 3.92:1 dark and 3.84:1 light against a 4.5:1 floor — and was adjusted until it
passed. Line numbers are the deliberate exception at ~2.5:1: a gutter should be
present without competing with the code.

lualine's `theme = "auto"` produced a grey-on-grey statusline (3.34:1), so
`lua/scheme/lualine.lua` builds the table from whichever palette is active.

The file explorer opens on the **right** (`<Space>e`), so toggling it doesn't shift
your code sideways.

`<Space>` is the leader key. `which-key` shows you the menu if you pause after it,
so you never have to memorise the rest.

---

## 3. Buffers, not tabs

Open files appear as tabs along the top. They are *buffers* — `<S-h>` and `<S-l>`
move between them, `<Space>bd` closes one, `<Space>1`–`<Space>9` jump directly.
`<Space>fb` gives you a searchable list, which beats cycling once you have a dozen open.

`<Space>bd` deletes the buffer but **leaves your split alone**, so closing a file in
a two-pane layout doesn't collapse the layout. `<Space>bD` discards unsaved changes,
`<Space>bo` closes everything else.

### Multi-cursor and replace

| Key | Does |
|---|---|
| `<C-n>` | add a cursor at the next match of the word or selection |
| `<C-p>` | skip this match |
| `<Space>ma` | a cursor on every match in the file |
| `<Space>mj` / `<Space>mk` | add a cursor below / above |
| `<C-LeftMouse>` | add a cursor where you click |
| `<Esc>` | clear the extra cursors |

`<Esc>` clears cursors when any exist and otherwise still clears the search
highlight, so the old behaviour is intact.

`<Space>sr` opens a search-and-replace buffer over the whole project — type a
pattern and a replacement, see every match live, apply selectively. `<Space>sw`
prefills the word under the cursor, `<Space>sf` limits it to the current file, and
in visual mode `<Space>sr` prefills the selection. Build output is excluded, so a
replace can't rewrite `node_modules` or `dist`.

### GitHub Actions

You have 27 workflow files across 8 repos (alongside 27 Jenkinsfiles, which none
of this touches).

| Key | Does |
|---|---|
| `<Space>Al` | list runs, then pick one to inspect, watch, re-run or open |
| `<Space>Ao` | logs of the latest run, in a read-only buffer you can search |
| `<Space>Af` | failed steps only |
| `<Space>Aw` | watch the running workflow live |
| `<Space>Ar` | re-run the failed jobs |
| `<Space>Ad` | dispatch a workflow |

**Dispatch always confirms, and prod has to be typed.** `deploy.yml` and
`rollback.yml` take an `environment` input whose options include `prod`, so a
keybind here can reach production. Choosing any non-prod value shows a summary and
waits for `y`; choosing prod makes you type the word `prod` before anything is
sent. There is no single-keypress path to a deploy.

Inputs come from the workflow's own `workflow_dispatch.inputs`, so choice inputs
offer exactly the options the yaml declares and string inputs prompt with their
description. The ref defaults to your current branch, and the summary shows it —
worth reading, since deploying `prod` from a feature branch is possible and the
summary is the only thing that tells you.

**One thing you need to do:** your `gh` token has no `workflow` scope, so
dispatching will fail until you run `gh auth refresh -s workflow`. Listing,
logs and watching all work without it.

### Pull requests

`<Space>pp` opens this branch's PR in the browser, `<Space>pc` starts one there,
and `<Space>pk` shows its checks in a buffer. Reviewing happens in the browser
(or `<Space>gm` for the whole branch as a diff here).

### Jira

**Any board at Awin.** `<Space>jB` lists every project you can see (74 today), then
that project's boards; pick one and the sprint and board views show *its* active
sprint. *All of Awin* makes search span every project. The choice is remembered,
and recent boards sit at the top of the list. `<Space>jm` (your open issues)
always covers every project, whichever board is selected. Under the hood this
uses a derived copy of jira-cli's config for other boards — your
`~/.config/.jira/.config.yml` is never edited.

`<Space>js` is the current sprint, `<Space>jb` is the board a column at a time,
`<Space>jm` is your own open issues, `<Space>jf` searches.

`<Space>jf` also jumps. Typing an issue key opens that issue instead of running
a text search for its name — `AR-991`, lowercase `ar-991`, or just `991`, which
is resolved against the project jira-cli is configured for. A key from another
project works too: `jira issue view` takes the key itself, so the jump is not
scoped to the current sprint, the board, or even the configured project.
Anything that is not a key is searched instead, using JQL's `text` field —
summary, description **and comments** — so an issue whose title says nothing but
whose comments say everything is still findable. The term gets a trailing `*`,
so `round` finds `rounding`.

It is worth knowing how this differs from the board's filter box. `~` is a
full-text index, not a substring match: it matches whole words and prefixes, and
Jira rejects a *leading* wildcard outright, so `ing` will never find `rounding`.
For true substring filtering, load a list first — `<Space>js` or `<Space>jb` —
and type in the picker, which filters on key, status, assignee and summary
together over the issues already fetched.

All four open a picker with a **preview pane that reads the whole issue** as you
move down the list — description, every comment, and the fields the board hides:
sprint, story points, epic, subtasks and linked issues. It is rendered as
markdown from Jira's own document format rather than scraped from the CLI's
terminal output, so it re-wraps to whatever width the split happens to be.

From inside the list you act on the highlighted issue without leaving it:

| In the picker | |
|---|---|
| `<CR>` | menu of everything below, if you'd rather not memorise the keys |
| `<C-t>` | move it to another column |
| `<C-a>` | assign it |
| `<C-c>` | comment on it |
| `<C-o>` | open it in the browser |
| `<C-v>` | open the full issue in its own split, to search and yank |

The columns offered by `<C-t>` are the statuses actually present in the sprint,
so they are your board's real columns and not a list baked into this repo.

The same five actions have direct keys — `<Space>jv` read, `<Space>jt` move,
`<Space>ja` assign, `<Space>jc` comment, `<Space>jo` open — and they work out
which issue you mean from the branch name. On `feature/AWIN-1841-rounding`,
`<Space>jc` comments on AWIN-1841 without asking. Failing that it reads the key
under the cursor, and failing that it prompts.

`<Space>jc` opens a scratch buffer rather than a prompt, so a comment can be as
long as it needs to be and can be edited before it goes. `<C-s>` posts it, `q`
throws it away.

`<Space>jj` drops to the raw `jira-cli` explorer in a float for anything this
layer doesn't wrap.

#### Setting it up

Everything shells out to [jira-cli](https://github.com/ankitpokhrel/jira-cli),
which the Brewfile installs. Three commands, once:

```sh
# 1. Create a token at
#    https://id.atlassian.com/manage-profile/security/api-tokens
#    `read -rs` keeps it out of your shell history.
read -rs JIRA_API_TOKEN && export JIRA_API_TOKEN

# 2. Configure jira-cli. Answer: Cloud, https://<your-site>.atlassian.net,
#    your work email, then pick your project and board.
jira init

# 3. Hand the token to the Keychain, and drop it from this shell.
security add-generic-password -s jira-api-token -a "$(jira me)" -U -w
unset JIRA_API_TOKEN
```

Then `:checkhealth nvim-config` — the **Jira** section walks the same four steps
in order and tells you which one is missing.

#### Where the credential lives

**This repo is public. Nothing here holds a token, a site URL or an email
address, and nothing should.**

- The token is in the macOS Keychain. Neovim reads it once per session and puts
  it in the environment of the `jira` process alone — never into `vim.env`, so
  it can't reach a `:terminal`, another plugin, or any other child process.
- The Keychain account is read from jira-cli's `login:` line rather than written
  into the Lua, which is why no address appears in this repo.
- jira-cli's own config is `~/.config/.jira/.config.yml`, outside this
  repository.
- If you rotate the token: re-run the `security add-generic-password` line above
  (`-U` updates in place), then `:lua require("config.jira").forget()` or
  restart, since the old one is cached for the session.

### Sessions and breadcrumbs

`<Space>qs` restores the session for the repo you're in — buffers, splits, folds
and cursor positions. `<Space>ql` restores the last one you had open anywhere,
`<Space>qd` stops the current one being saved. Terminals are deliberately left
out: restoring a dead shell in a float is never what you wanted.

The winbar shows `Class > method` for the file you're in; `<Space>;` jumps through
it. It's suppressed in the tree, terminals, lists and diff views.

### Windows and terminals

`<C-h/j/k/l>` moves between splits — including **from inside a terminal**, so you
don't have to escape terminal mode first. `<Space>wm` maximises the current split
and restores it, `<Space>wo` closes every other window.

Terminals: `<Space>tt` floats one, `<Space>th` / `<Space>tv` put one at the
bottom / on the right, `<Space>tn` opens one at the project root, `<Space>tl`
lists and switches between them, `<Space>t1`–`<Space>t3` jump directly,
`<Space>tx` closes the current one and `<Space>tX` closes them all (dev servers
are left running — `<Space>nx` stops those).

Every terminal — and Claude — has a bar across the top with **⇱ float ⬓ bottom
◨ right ✕ hide** buttons, so you can move one or put it away with a click.
`<Space>tm` does the same from the keyboard, cycling float → bottom → right.

And `q` closes the read-only windows that otherwise strand you — help, quickfix,
`:checkhealth`, `:LspInfo`, blame.

### Fonts and icons

The icons are Nerd Font glyphs, and they only exist in a *patched* font. If you
see question marks instead — in the dashboard, the gutter, the statusline, the
file tree — the terminal is not using one. `:checkhealth nvim-config` says
whether a Nerd Font is installed and prints a probe across the four codepoint
ranges that fail independently, so you can tell "no font" from "wrong font".

Being installed is not the same as being selected. In iTerm2 the setting is
**Settings → Profiles → Text → Font**, with *"use a different font for
non-ASCII text"* left unchecked, and a font change only reaches sessions started
after it — quit and reopen the terminal rather than opening a new tab.

The git gutter is deliberately exempt: its marks are plain block characters
(`▎`, `▁`, `▔`) that render in any font, so the one signal you read constantly
survives a broken font.

**If you would rather not depend on the font at all**, there is a switch:

```lua
vim.g.have_nerd_font = false   -- lua/config/options.lua
```

`false` — the default — gives plain-text stand-ins everywhere: `E` `W` `H` `I`
for the diagnostic signs, a thin `│` between statusline components and no
section separator, `+ ~ ? *` for the file tree's git column. Nothing is lost
except decoration, and it renders in any terminal, including one you ssh into
or do not control. Flip it to `true` for the glyphs. Both sets live in
`lua/config/icons.lua`, one table each, with the codepoints in the comments so a
glyph that goes missing is still recoverable from a diff.

### Folds, the quickfix list, and files that move underneath you

Folding is treesitter's, not indentation's, so it folds where a method or a
template block actually ends. Files open unfolded; `za` toggles the block under
the cursor, `zM` collapses everything to its headings and `zR` opens it all back
up. On a filetype with no parser there are simply no folds rather than an error.

`]q` and `[q` walk the quickfix list and wrap at either end. Three things fill
that list — merge conflicts from `<Space>gX`, search results sent from grug-far,
and whatever `<Space>xq` last opened — so it is worth being able to step through.

**Files that change outside the editor are picked up automatically.** `ng
generate`, a lazygit branch switch, prettier on save and Claude's edits all write
behind the buffer's back; the buffer re-reads when you come back to it and says
so. Nothing is silently discarded — a buffer with unsaved changes still prompts.

Markdown and commit messages are spell-checked, including the Jira comment
composer; `z=` offers corrections. Code buffers are untouched, and so is the
read-only issue view — only what you are actually writing gets underlined.

---

## 4. Angular

Three language servers attach to a component file:

- **vtsls** — TypeScript: definitions, references, rename, auto-import
- **angularls** — templates: component properties in `.html`, directive jumps
- **eslint** — your repo's own flat config, diagnostics as you type

**Each project uses its own toolchain.** Your repos span Angular 18, 19 and 21,
ESLint 9 and 10, Prettier 2 and 3. The Angular server is started per project with
its probe path pointed at that repo's `node_modules` first, and Prettier is
resolved from `node_modules/.bin`. Nothing global overrides your team's config.

Repos that don't ship `@angular/language-service` fall back to a pinned copy in
`~/.local/share/nvim/angular-fallback`. Project-local always wins.

### Moving around a component

`<Space>or` (or right-click → *Related files…*) lists where this component or
service is wired in — the **route** that loads it, the **module** that declares
it, the **store** files, the **templates** that render its selector, its spec, and
every other usage — and jumps there with a preview.

A component is up to four files sharing a stem. These jump between them:

| Key | Goes to |
|---|---|
| `<Space>ot` | the `.ts` |
| `<Space>oh` | the `.html` template |
| `<Space>os` | the `.scss` styles |
| `<Space>op` | the `.spec.ts` |
| `<Space>oo` | cycle through whichever exist |

`prepayment-ui` writes most templates inline, so `<Space>oh` there tells you the
component uses an inline template rather than opening an empty file. The same
keys work for services and pipes, where the useful pair is the file and its spec.

### Renaming files

Rename or move a file in the tree and every import that pointed at it is
rewritten. `vtsls` has `updateImportsOnFileMove` on, and neo-tree's rename events
are wired through to it, so the language server hears about the move. Without that
wiring the rename happens silently and you find out at compile time.

`<Space>cI` organizes imports and `<Space>cR` removes unused ones. `<Space>cR` is
deliberately bound to *remove unused imports* rather than TypeScript's "remove all
unused code", which would also delete unused variables and functions.

### Angular CLI

`<Space>ng` is the Angular CLI prefix (it's a prefix only, never an action, so
you never sit through a timeout).

| Key | Generates |
|---|---|
| `<Space>ngg` | anything — a picker of every schematic this repo offers |
| `<Space>ngc` | component |
| `<Space>ngs` | service |
| `<Space>ngp` | pipe |
| `<Space>ngd` | directive |
| `<Space>ngu` | guard |
| `<Space>ngx` | any other `ng` command — version, update, add, cache, config |

Three things it does that a shell alias doesn't:

**The name prefills from where you are.** Generating a component while editing
`src/app/ui/data-table-shell/` prefills `ui/data-table-shell/`, so the new files
land beside the code you're working on rather than at the app root.

**It works out which project you're in.** None of your repos set
`defaultProject` (Angular dropped it), and `awin-angular-libraries` has fifteen —
the project is inferred from the path of the file you're editing and passed as
`--project`, so you're not prompted.

**Nothing is written until you've seen it.** Every generate runs `--dry-run`
first and shows the exact file list; `y` creates them, `q` cancels. Afterwards the
new `.ts` opens automatically. This is the part WebStorm's dialog gets right.

The schematic list is read live from `ng generate --help` in that workspace, so
it reflects what's actually installed — your `angular-eslint` schematics appear in
`advertiser-payments-ui` and wouldn't in a repo without them.

In `<Space>ngx`, `serve` / `build` / `test` / `lint` go through the repo's
`package.json` script when one exists, so `advertiser-payments-ui` still runs its
`load-env.mjs` prelude. Everything else runs `ng` directly.

### Running the project

Every front-end repo here has the same shape — `yarn start` serves the app,
`yarn wiremock` serves its stubs — and remotes normally run inside **shell-ui**.
So, from any repo in `~/projects`:

| Key | Does |
|---|---|
| `<Space>ns` | `yarn start` + `yarn wiremock` for this project |
| `<Space>nS` | pick a **shell-ui branch**, then run shell-ui + its wiremock + this project |
| `<Space>nx` | stop everything |
| `<Space>nX` / `<Space>nR` | stop / restart one |
| `<Space>nv` | show a server's output |
| `<Space>ae` | send a server's output to Claude to fix |

The statusline shows what is running — `● app  ● shell@RAP-1999  ● shell-mock` —
coloured by state (starting, ready, crashed). **Click it** for the same menu;
right-click stops everything. When nothing is running it reads `▶ Run`.

What `<Space>nS` does with shell-ui, in `~/projects/shell-ui`:

- switches it to the branch you picked with `git switch` — and **refuses** if it
  has uncommitted changes, rather than carrying them across;
- runs `yarn install` first only if `yarn.lock` differs between the two branches;
- runs **shell-ui's** wiremock, not the project's: shell-ui owns the stubs the
  host needs. A project's own wiremock only runs when you start it standalone.

The servers run in hidden terminals: they don't clutter the window, they keep
their output after a crash (you get a notification with the exit code), and
quitting Neovim stops them. Each is started as the named yarn script through
`direnv exec`, so a repo's `.envrc` applies.

`<Space>nr` lists every script in `package.json` and runs the one you pick. It
runs the *named script*, never a reconstructed command, so env preludes like
`node scripts/load-env.mjs dev && …` still run.

A daily loop:

1. `<Space><Space>` and type `user-list.component` to open it
2. `gd` on a service to read it, `<C-o>` to come back
3. `<Space>cr` to rename a symbol across the whole app
4. `<Space>ca` on a red squiggle for the quick fix
5. `<Space>cf` to apply every ESLint autofix in the file
6. Save — Prettier formats with *this repo's* version
7. `<Space>ns` to serve it (or `<Space>nS` inside shell-ui)

If a repo has no `node_modules`, run `yarn install` first — the language servers
have nothing to read until then.

---

### Checking the whole project

The language server only knows about files you have open. `<Space>cc` runs
Angular's compiler (`ngc` — TypeScript **and templates**, the same strict checks
`ng build` does), `tsc` over the specs, and ESLint over `src/`, side by side in
the background — about 15 seconds on advertiser-payments-ui. Problems go to the
quickfix list and open in Trouble; `]q` / `[q` walk them. The statusline shows
`✓ checks` or `✗ 12` — click it for the list, right-click to run again.
`<Space>cy` / `<Space>cl` run just types / just lint.

**Before every push** (`<Space>gp`, *Commit and push*, the Git menu) the same
checks run plus the headless test suite, and the push only happens if they
pass — or if you choose *Push anyway*. `<Space>uP` turns that off. (lazygit's
own push isn't gated.)

**Auto-save:** a changed file is saved when you switch to another file or
window, or when Neovim loses focus — so the dev server and tests always see what
is on screen. `<Space>ua` toggles it.

**Errors in full:** the line under the cursor shows its diagnostics in full
underneath it; other lines keep the short version. `<Space>ud` toggles it.

### Tests in the gutter

Open a spec and every `describe` and `it` has a **▶** in the gutter. **Click it**
(or `<Space>nT` on the line) to run just that test; `<Space>nF` runs the whole
spec. When the run ends the marks turn into **✓** and **✗**, and a `describe` is
✗ if anything inside it failed. `<Space>nf` shows the output; on a ✗ line,
`<Space>aF` (or right-click → *Claude: fix failing test*) hands Claude the test,
its location and the failure.

Karma can't be told "run only the test called X" through `ng test`, so a single
test runs the way you'd do it by hand: a copy of the spec, with that `it` turned
into `fit`, sits beside it for the run and is deleted afterwards — your file is
never edited. The copy is called `*.nvim-focus.spec.ts` and is in the global
gitignore.

**Coverage:** `<Space>nC` runs the spec with `--code-coverage`; the line numbers
of the files it touched turn green (ran) or red (never ran). `<Space>uC` toggles
the colours. It reads the HTML report Angular's default Karma setup writes, so no
`karma.conf` changes are needed, and warns when a file has changed since.

### Running tests

Every repo here uses Karma + Jasmine, so there is no neotest adapter. Instead the
keys drive the repo's own test script with Karma's `--include`:

| Key | Runs |
|---|---|
| `<Space>nt` | just this component's spec |
| `<Space>na` | the whole suite, once |
| `<Space>nw` | the whole suite, watching |
| `<Space>nl` | lint |
| `<Space>nr` | pick any script |

`<Space>nt` works from the `.ts`, the `.html` or the `.scss` — it resolves the
component's spec either way. Where a repo defines `test-headless` it uses that,
so no Chrome window appears; otherwise it appends `--watch=false` for a one-shot
run — a focused run takes seconds rather than the whole suite.

## 5. CSV files

You have 541 of them. Open one and it renders as an aligned table, quoted fields
and all — `<Space>uv` toggles back to raw text, `<Tab>` and `<S-Tab>` jump between
fields.

`<Space>uh` controls the header row, and it's off by default on purpose: the
`awin-localization` exports have no header, so treating their first translation as
a column title would be wrong. Turn it on for the files that do have one, like
`retrieve-duplicate-pm/duplicate.csv`.

Quoted fields containing commas stay in one column — verified on a row where a
naive split gives 7 columns and the correct answer is 3.

**Files over 1.5 MB don't render automatically.** snacks' bigfile guard gives them
the `bigfile` filetype to keep the editor responsive, so `aa_DJ.awin.csv` (1.6 MB,
11,196 rows) opens as plain text with a note telling you to press `<Space>uv`. The
manual toggle works fine on it.

## 6. Terraform and infrastructure

`terraform-ls` gives completion and hover docs on `aws_*` resources, and
`terraform fmt` runs on save. `tflint` adds lint diagnostics.

**Your `make plan` / Docker workflow is untouched.** The local terraform binary
(1.16) is used only by the editor; your repos still pin 1.6.1 in `versions.json`
and run it in a container. The two never meet.

`terragrunt.hcl`, `root.hcl` and `common.hcl` get syntax highlighting but no
language server — there isn't a good one for Terragrunt.

YAML gets SchemaStore validation, so `docker-compose.yml`, `catalog-info.yaml`
and GitHub workflows are checked as you type. Dockerfiles and shell scripts have
servers too.

---

## 7. Git, and learning lazygit

`<Space>gg` opens lazygit for whatever repo the current file is in. It's
configured with `delta` for readable diffs and `nvim` as its editor.

**Learn it in this order — don't read the whole keymap list.**

*Stage and commit.* Panels are numbered `1`–`5`; `Tab` cycles them. In the Files
panel (`2`), `Space` stages a file, `Enter` opens it to stage individual lines
(`Space` on a line, `v` to select a range), `c` writes a commit message, `C` opens
Neovim for a long one.

*Branch.* Panel `3` is Branches. `n` creates one, `Space` checks one out,
`d` deletes, `M` merges into the current branch, `r` rebases.

*Rebase interactively.* In panel `4` (Commits), `e` starts an interactive rebase
from that commit. Then on each commit: `s` squash, `f` fixup, `r` reword,
`d` drop, `Ctrl-j`/`Ctrl-k` reorder. `m` opens the rebase menu to continue or abort.

*Cherry-pick.* In Commits, `Shift-c` copies a commit, `Shift-v` pastes it onto
your branch.

*Conflicts.* Conflicted files show in the Files panel. `Enter` on one gives you
the hunks — pick a side, or `e` to open it in Neovim and edit properly.

`?` inside lazygit shows the keys for whatever panel you're in. `q` quits.

For small things you don't need lazygit at all: `]h`/`[h` jump between changed
hunks, `<Space>ghs` stages the hunk under the cursor, `<Space>ghp` previews it,
`<Space>gb` blames the line; `<Space>ug` leaves the blame on every line as you
move.

To review a whole branch before opening a PR: `<Space>gm` diffs everything on
your branch against master in a proper two-pane view. `<Space>gq` closes it.

### Git, JetBrains-style

`<Space>gv` — or right-click → *Git…*, or right-click the branch in the
statusline — is one menu with the file, the change under the cursor and the
repository: add, unstage, **rollback**, show diff, history, annotate, compare with
a branch, commit, commit and push, push, pull, fetch, branches, **stash /
unstash**, undo last commit, rollback all. **Click a change marker** in the
gutter to show, stage or roll back that change.

| Key | Does |
|---|---|
| `<Space>gA` / `<Space>gR` | add / rollback this file (rollback asks first) |
| `<Space>gk` / `<Space>gK` | commit… / commit and push… (offers to stage everything if nothing is staged) |
| `<Space>gp` / `<Space>gP` | push (sets the upstream the first time) / pull with rebase and autostash |
| `<Space>gn` | branches: switch — offering to stash if you have changes — or create one |
| `<Space>gS` / `<Space>gU` | stash (with untracked files) / unstash: pop, apply or drop, with the diff as preview |
| `<Space>gz` | undo the last commit, keeping its changes staged (warns if it's pushed) |

Anything that throws work away asks first. lazygit (`<Space>gg`) is still there
for everything else.

### Merge conflicts

**`<Space>gx` starts it.** It opens the three-pane merge view — OURS on the left,
the working copy in the middle, THEIRS on the right — the same shape as
WebStorm's merge dialog. If there's nothing to merge it says so rather than
opening an empty diff and leaving you to work out why.

Inside that view: `<Space>co` takes ours, `<Space>ct` takes theirs, `<Space>cb`
takes both, `<Space>cn` takes neither, and `]x` / `[x` move between conflicts.
`<Space>cO` and `<Space>cT` take a whole file at once when one side wins
outright.

git-conflict.nvim used to let you resolve a small conflict in the buffer itself,
without opening the merge view. It was dropped: upstream stopped in December
2024, and it called `vim.diagnostic.disable()`, which Neovim 0.12 removed, so it
needed a workaround here to run at all. The merge view is one keypress away and
does the same job.

`<Space>gX` puts every conflicted file in the quickfix list, each entry pointing
at its first marker — useful when a rebase breaks eight files at once.

Once the markers are gone, `<Space>gg` for lazygit: stage the file, then continue
the merge or rebase from its rebase menu (`m`).

### Two git settings worth having

Neither is set on this machine, and both make conflicts markedly easier. Run them
once, in a terminal:

    git config --global merge.conflictstyle zdiff3
    git config --global rerere.enabled true

The first makes conflict markers include the **common ancestor** between `|||||||`
and `=======`, not just the two competing versions. Without it you can't tell
which side actually changed — that's most of why a raw conflict is hard to read.

The second makes git record how you resolved a conflict and replay it
automatically when the same one reappears. On a long-lived branch being rebased
repeatedly, it's the difference between tedious and unbearable.

Use `--local` instead of `--global` if you'd rather set them per repository.

---

## 8. Claude

`<Space>ac` opens Claude, sharing the project directory. The `✦ Claude` button in
the statusline does the same; right-click it to move the window.

The reason it's a plugin and not just a terminal: select some lines, press
`<Space>as`, and Claude receives them as a real file reference. When it proposes
an edit, the edit opens as a **native Neovim diff** — your version on the left,
its version on the right. `<Space>aa` accepts, `<Space>ad` rejects. You review
before anything touches your file.

**Where it sits.** `<Space>ap` (or the `⇱ ⬓ ◨` buttons on its window bar) puts it
on the right, at the bottom, floating, or on the left. The choice is remembered,
and moving it never interrupts the conversation. `<Space>a=` / `<Space>a-` resize
it, or drag the separator.

**Conversations.** `<Space>aC` continues the last conversation in this project.
`<Space>ar` lists earlier ones by their first prompt and age, and resumes the one
you pick. `<Space>an` starts fresh.

**Asking about code** — all of these work on the line you're on or a selection,
and start Claude with the question if it isn't running yet:

| Key | Does |
|---|---|
| `<Space>aq` | ask a question about this line / selection |
| `<Space>ax` | fix the diagnostics on it |
| `<Space>ai` | explain it |
| `<Space>at` | write tests for this component |
| `<Space>aR` | review your uncommitted changes |
| `<Space>ae` | hand it a dev server's error output |
| `<Space>ab` | add the whole file to its context |

The same entries are in the right-click menu.

---

## 9. When something breaks

| Symptom | Check |
|---|---|
| No completion or `gd` does nothing | `:checkhealth vim.lsp` — is a server attached? |
| Angular template completion missing | Does the repo have `node_modules`? Run `yarn install`. |
| ESLint silent | `:LspInfo` — is `eslint` attached? Does the repo have a flat config? |
| Save doesn't format | `:ConformInfo` shows which formatter ran and whether it was found |
| Formatting the wrong style | Expected if the repo has no Prettier installed — nothing runs by design |
| Terraform hover empty | `terraform` must be on `PATH`: `which terraform` |
| Plugin looks broken | `:Lazy` then `S` to sync, or `:Lazy restore` to go back to the lockfile |
| Server missing | `:Mason` to see and install servers |
| Something is very wrong | `git -C ~/.config/nvim diff` — you changed something |

`:checkhealth` on its own runs everything.

---

## 10. Updating

- `:Lazy` → `U` updates plugins. `lazy-lock.json` records exact versions; commit it.
- `:Mason` → `U` updates language servers.
- `:TSUpdate` updates treesitter parsers.

If an update breaks something: `:Lazy restore` puts every plugin back to the
lockfile, and `git checkout lazy-lock.json` puts the lockfile back too.
