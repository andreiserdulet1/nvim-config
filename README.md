# Neovim IDE — Angular / TypeScript + Terraform

A hand-rolled Neovim config, ~30 plugins, built for two jobs: Angular front-ends
and AWS infrastructure. Everything here is readable in about twenty minutes.

Start it with `v` (the alias already in your `~/.zshrc`) or `nvim`.
Press `<Space>?` inside Neovim at any time for the keymap cheatsheet.

**Web guide:** https://claude.ai/code/artifact/fa81e147-7724-4e98-9a71-0a9f36c71547

---

## 1. Layout

```
~/.config/nvim/
├── init.lua                 leader key + bootstrap
├── lua/config/
│   ├── options.lua          editor behaviour, diagnostics, filetypes
│   ├── keymaps.lua          keymaps that don't belong to a plugin
│   ├── lazy.lua             plugin manager bootstrap
│   ├── cheatsheet.lua       the <Space>? popup
│   └── projects.lua         project switcher over ~/projects
└── lua/plugins/
    ├── ui.lua               colorscheme, statusline, buffer tabs, dashboard
    ├── editor.lua           telescope, neo-tree, which-key, flash, treesitter
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
| `<Space>ac` | Claude |
| `<Space>?` | The full cheatsheet |

`<Space>ut` switches between the light and dark palette; the choice is remembered
next time you start. Both match the web guide exactly.

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

`<Space>pl` lists this repo's PRs, `<Space>pp` opens the one for your branch,
`<Space>pr` starts a review and `<Space>pR` submits it. `<Space>pi` for issues,
`<Space>ps` to search. It drives the `gh` CLI you're already logged into.

### Sessions and breadcrumbs

`<Space>qs` restores the session for the repo you're in — buffers, splits and
cursor positions. `<Space>ql` restores the last one you had open anywhere,
`<Space>qd` stops the current one being saved.

The winbar shows `Class > method` for the file you're in; `<Space>;` jumps through
it. It's suppressed in the tree, terminals, lists and diff views.

### Windows and terminals

`<C-h/j/k/l>` moves between splits — including **from inside a terminal**, so you
don't have to escape terminal mode first. `<Space>wm` maximises the current split
and restores it, `<Space>wo` closes every other window.

Terminals: `<Space>tt` floats one, `<Space>tn` opens one at the project root,
`<Space>tl` lists and switches between them, `<Space>t1`–`<Space>t3` jump directly,
`<Space>tx` closes the current one and `<Space>tX` closes them all.

And `q` closes the read-only windows that otherwise strand you — help, quickfix,
`:checkhealth`, `:LspInfo`, blame.

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

`<Space>nr` lists the scripts in this repo's `package.json` and runs the one you
pick with `yarn`, in a terminal at the project root. It runs the *named script*,
never a reconstructed command — which is why `advertiser-payments-ui` correctly
runs its `load-env.mjs` prelude before `ng test`.

A daily loop:

1. `<Space><Space>` and type `user-list.component` to open it
2. `gd` on a service to read it, `<C-o>` to come back
3. `<Space>cr` to rename a symbol across the whole app
4. `<Space>ca` on a red squiggle for the quick fix
5. `<Space>cf` to apply every ESLint autofix in the file
6. Save — Prettier formats with *this repo's* version
7. `<Space>tn` for a terminal at the project root, then `yarn start`

If a repo has no `node_modules`, run `yarn install` first — the language servers
have nothing to read until then.

---

### Running tests

Every repo here uses Karma + Jasmine, so there is no neotest adapter. Instead the
keys drive the repo's own test script with Karma's `--include`:

| Key | Runs |
|---|---|
| `<Space>nt` | just this component's spec |
| `<Space>na` | the whole suite, once |
| `<Space>nw` | the whole suite, watching |
| `<Space>ns` | the dev server |
| `<Space>nl` | lint |
| `<Space>nr` | pick any script |

`<Space>nt` works from the `.ts`, the `.html` or the `.scss` — it resolves the
component's spec either way. Where a repo defines `test-headless` it uses that,
so no Chrome window appears; otherwise it appends `--watch=false` for a one-shot
run. In `advertiser-payments-ui` a focused run is ~15 seconds against 2 tests
rather than the full 136-spec suite.

## 5. Debugging

`<Space>db` sets a breakpoint, `<Space>dc` starts. The debugger drives Chrome
through `js-debug-adapter` and maps the running bundle back to your `.ts` files.

| Key | Does |
|---|---|
| `<Space>db` / `<Space>dB` | breakpoint / conditional breakpoint |
| `<Space>dc` | start or continue |
| `<Space>di` `<Space>do` `<Space>dO` | step into / over / out |
| `<Space>du` | show or hide the panels |
| `<Space>dw` | watch the expression under the cursor |
| `<Space>dt` | stop |

Start the dev server first (`<Space>ns`), then `<Space>dc` and pick
**"launch Chrome on the dev server"**. Chrome opens in a separate profile, so your
normal session and its tabs are untouched. The alternative config attaches to a
Chrome you started yourself with `--remote-debugging-port=9222`.

Nothing debug-related loads until you press a `<Space>d` key, so it costs nothing
on startup if you never use it.

**If a breakpoint goes hollow and never hits**, the source maps aren't lining up —
adjust `source_map_overrides` in `lua/plugins/debug.lua`. Angular's dev server
changed how it emits map paths in v17, so this is the setting most likely to need
a nudge on a given repo.

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
`<Space>gb` blames the line.

To review a whole branch before opening a PR: `<Space>gm` diffs everything on
your branch against master in a proper two-pane view. `<Space>gq` closes it.

### Merge conflicts

The keys are the same whether you use the three-pane view or fix the file in
place: `<Space>co` takes ours, `<Space>ct` takes theirs, `<Space>cb` takes both,
`<Space>cn` takes neither, and `]x` / `[x` move between conflicts.

**For anything non-trivial, `<Space>gx`.** It opens the three-pane merge view —
OURS on the left, the working copy in the middle, THEIRS on the right — the same
shape as WebStorm's merge dialog. `<Space>cO` and `<Space>cT` take a whole file at
once when one side wins outright. If there's nothing to merge it says so rather
than opening an empty diff and leaving you to work out why.

**For a two-line conflict, just open the file.** Conflicted regions are
highlighted in place and the same keys work, with no extra windows and no mode to
enter. TypeScript diagnostics are suppressed while markers are present, since a
conflicted file isn't valid code and the errors are noise.

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

`<Space>ac` opens Claude in a split, sharing the project directory.

The reason it's a plugin and not just a terminal: select some lines, press
`<Space>as`, and Claude receives them as a real file reference. When it proposes
an edit, the edit opens as a **native Neovim diff** — your version on the left,
its version on the right. `<Space>aa` accepts, `<Space>ad` rejects. You review
before anything touches your file.

`<Space>ab` adds the whole current file to its context. `<Space>tc` is a plain
`claude` terminal if you'd rather use the CLI directly.

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
