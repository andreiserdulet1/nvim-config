-- Language servers, completion, and the per-project Angular resolution.
return {

  -- Mason: downloads and manages the language servers and CLI tools ---------
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    opts = { ui = { border = "rounded" } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = "VeryLazy",
    opts = {
      ensure_installed = {
        -- Angular / TypeScript
        "vtsls",                      -- TypeScript server (faster than ts_ls in monorepos)
        "angular-language-server",    -- provides the `ngserver` binary
        "eslint-lsp",                 -- vscode-eslint; reads each repo's flat config
        "html-lsp",
        "css-lsp",
        -- Infrastructure
        "terraform-ls",
        "tflint",                     -- not in Homebrew any more, so Mason supplies it
        "yaml-language-server",
        "json-lsp",
        "dockerfile-language-server",
        "bash-language-server",
        "shfmt",
        -- Debugging (see plugins/debug.lua)
        "js-debug-adapter",
        -- Editing this config
        "lua-language-server",
        "stylua",
      },
      run_on_start = true,
      auto_update = false,
    },
  },

  -- Completion --------------------------------------------------------------
  {
    "saghen/blink.cmp",
    version = "*",                     -- use a release: it ships prebuilt binaries
    event = "InsertEnter",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = {
        preset = "default",            -- <C-y> accepts, <C-n>/<C-p> cycle
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        ghost_text = { enabled = false },
        accept = { auto_brackets = { enabled = true } },
      },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      signature = { enabled = true },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },

  -- Autocomplete for editing this Neovim config itself ----------------------
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } },
    },
  },

  -- The LSP configuration itself -------------------------------------------
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "mason-org/mason.nvim", "saghen/blink.cmp" },
    config = function()
      ----------------------------------------------------------------------
      -- Shared capabilities: tell every server what blink.cmp can render.
      ----------------------------------------------------------------------
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities({}, true),
      })

      ----------------------------------------------------------------------
      -- Per-server overrides. nvim-lspconfig ships the base definitions;
      -- these tables are merged on top of them.
      ----------------------------------------------------------------------

      -- TypeScript. Formatting is left to Prettier via conform.nvim.
      vim.lsp.config("vtsls", {
        settings = {
          typescript = {
            updateImportsOnFileMove = { enabled = "always" },
            inlayHints = {
              parameterNames = { enabled = "literals" },
              variableTypes = { enabled = false },
              propertyDeclarationTypes = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
            },
            preferences = { importModuleSpecifier = "shortest" },
          },
          vtsls = {
            experimental = { completion = { enableServerSideFuzzyMatch = true } },
          },
        },
      })

      -- ESLint. Runs each project's own ESLint against its own flat config,
      -- so the Awin boundaries rules in eslint.config.boundaries.js apply.
      vim.lsp.config("eslint", {
        settings = {
          useFlatConfig = true,
          workingDirectories = { mode = "auto" },
          -- Lint Angular inline templates too.
          validate = "on",
        },
      })

      -- Terraform. Uses the Homebrew terraform binary purely for the editor;
      -- your Makefile/Docker workflow is untouched.
      vim.lsp.config("terraformls", {
        settings = {
          terraform = {
            validation = { enableEnhancedValidation = true },
          },
        },
      })

      -- YAML with SchemaStore-backed validation.
      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            keyOrdering = false,
            schemaStore = { enable = true, url = "https://www.schemastore.org/api/json/catalog.json" },
            validate = true,
          },
        },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            diagnostics = { globals = { "vim" } },
            telemetry = { enable = false },
          },
        },
      })

      ----------------------------------------------------------------------
      -- Turn the servers on.
      ----------------------------------------------------------------------
      vim.lsp.enable({
        "vtsls",
        "eslint",
        "terraformls",
        "yamlls",
        "jsonls",
        "dockerls",
        "bashls",
        "html",
        "cssls",
        "lua_ls",
      })

      ----------------------------------------------------------------------
      -- Angular: started by hand, because the language server must be told
      -- where THIS project's node_modules live.
      --
      -- Your repos run Angular 18, 19 and 21. A single global language
      -- server would mis-parse most of them. The probe locations below put
      -- the project's own node_modules first, so each repo gets a language
      -- server backed by its own @angular/* and typescript versions.
      ----------------------------------------------------------------------
      local function start_angular(bufnr)
        local root = vim.fs.root(bufnr, { "angular.json", "project.json", "nx.json" })
        if not root then return end   -- not an Angular project; nothing to do

        local mason = vim.fn.stdpath("data") .. "/mason"
        local ngserver = mason .. "/bin/ngserver"
        if vim.fn.executable(ngserver) == 0 then return end

        -- Probe order matters. The project's own node_modules comes first, so
        -- a repo always gets a language server backed by its own Angular and
        -- TypeScript. Only if the repo doesn't ship @angular/language-service
        -- (advertiser-payments-ui, for one) do we fall back to the pinned copy
        -- in angular-fallback/, and finally to whatever Mason bundled.
        local probe = table.concat({
          root .. "/node_modules",
          vim.fn.stdpath("data") .. "/angular-fallback/node_modules",
          mason .. "/packages/angular-language-server/node_modules",
        }, ",")

        vim.lsp.start({
          name = "angularls",
          cmd = {
            ngserver,
            "--stdio",
            "--tsProbeLocations", probe,
            "--ngProbeLocations", probe,
          },
          root_dir = root,
          capabilities = require("blink.cmp").get_lsp_capabilities({}, true),
        }, { bufnr = bufnr })
      end

      local angular_fts = { typescript = true, html = true, htmlangular = true }

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "typescript", "html", "htmlangular" },
        callback = function(ev) start_angular(ev.buf) end,
      })

      -- lazy.nvim defers BufReadPre into its own LazyFile event, which fires
      -- *after* FileType. That means the autocmd above misses the very first
      -- file you open. Sweep the buffers that already exist so the first
      -- component you open gets a language server like every one after it.
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and angular_fts[vim.bo[buf].filetype] then
          start_angular(buf)
        end
      end

      ----------------------------------------------------------------------
      -- Keymaps, applied only to buffers that actually have a server.
      ----------------------------------------------------------------------
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local function map(keys, fn, desc, mode)
            vim.keymap.set(mode or "n", keys, fn, { buffer = ev.buf, desc = "LSP: " .. desc })
          end

          map("gd", "<cmd>Telescope lsp_definitions<cr>", "Go to definition")
          map("gr", "<cmd>Telescope lsp_references<cr>", "References")
          map("gi", "<cmd>Telescope lsp_implementations<cr>", "Implementation")
          map("gy", "<cmd>Telescope lsp_type_definitions<cr>", "Type definition")
          map("gD", vim.lsp.buf.declaration, "Declaration")
          map("K", function() vim.lsp.buf.hover({ border = "rounded" }) end, "Hover docs")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "v" })
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>cs", vim.lsp.buf.signature_help, "Signature help")

          -- ESLint's fix-all command, only bound where ESLint is attached.
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client.name == "eslint" then
            map("<leader>cf", "<cmd>LspEslintFixAll<cr>", "ESLint fix all")
          end

          -- Inlay hints: inferred types shown inline. Off by default so the
          -- screen stays calm; toggle when you want them.
          if client and client:supports_method("textDocument/inlayHint") then
            map("<leader>ci", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }),
                { bufnr = ev.buf })
            end, "Toggle inlay hints")
          end
        end,
      })
    end,
  },
}
