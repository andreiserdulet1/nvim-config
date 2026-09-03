-- Formatting (conform.nvim) and extra linting (nvim-lint).
--
-- The rule this file exists to enforce: every project formats with ITS OWN
-- tooling. Your repos run Prettier 2.3 (prepayment-ui) alongside Prettier 3.5
-- (commissions-ui), and two repos have no Prettier at all. A single global
-- formatter would silently rewrite files against the team's config.
return {

  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cF",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        mode = { "n", "v" },
        desc = "Format buffer",
      },
      {
        "<leader>uf",
        function()
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify("Format on save: " .. (vim.g.disable_autoformat and "OFF" or "ON"))
        end,
        desc = "Toggle format on save",
      },
    },
    opts = function()
      -- True only when the project actually configures Prettier. Without this
      -- guard, saving a file in advertiser-payments-ui or
      -- billing-invoice-history-ui (neither has Prettier) would reformat it
      -- against a default style nobody agreed to.
      local function has_prettier_config(ctx)
        local found = vim.fs.find({
          ".prettierrc", ".prettierrc.json", ".prettierrc.yml", ".prettierrc.yaml",
          ".prettierrc.js", ".prettierrc.cjs", ".prettierrc.mjs",
          "prettier.config.js", "prettier.config.cjs", "prettier.config.mjs",
          ".prettierrc.toml",
        }, { upward = true, path = ctx.dirname, stop = vim.env.HOME })
        if #found > 0 then return true end

        -- Prettier can also be configured via a "prettier" key in package.json.
        local pkg = vim.fs.find("package.json", {
          upward = true, path = ctx.dirname, stop = vim.env.HOME,
        })[1]
        if pkg then
          local ok, content = pcall(vim.fn.readfile, pkg)
          if ok then
            local decoded = vim.json.decode(table.concat(content, "\n"), { luanil = { object = true } })
            if type(decoded) == "table" and decoded.prettier ~= nil then return true end
          end
        end
        return false
      end

      return {
        -- conform resolves `prettier` from the project's node_modules/.bin
        -- before falling back to anything global, so each repo gets its own
        -- major version automatically.
        formatters = {
          prettier = { condition = has_prettier_config },
        },
        formatters_by_ft = {
          typescript = { "prettier" },
          javascript = { "prettier" },
          typescriptreact = { "prettier" },
          javascriptreact = { "prettier" },
          html = { "prettier" },
          htmlangular = { "prettier" },
          css = { "prettier" },
          scss = { "prettier" },
          json = { "prettier" },
          jsonc = { "prettier" },
          yaml = { "prettier" },
          markdown = { "prettier" },
          terraform = { "terraform_fmt" },
          hcl = { "terraform_fmt" },
          ["terraform-vars"] = { "terraform_fmt" },
          sh = { "shfmt" },
          bash = { "shfmt" },
          lua = { "stylua" },
        },
        format_on_save = function(bufnr)
          if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return nil
          end
          return { timeout_ms = 3000, lsp_format = "never" }
        end,
        notify_on_error = true,
      }
    end,
  },

  -- nvim-lint covers the linters that have no language server.
  -- TypeScript is deliberately absent: ESLint runs as an LSP (see lsp.lua),
  -- which is far faster than shelling out to eslint on every save.
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        terraform = { "tflint" },
        ["terraform-vars"] = { "tflint" },
      }

      -- tflint must run with the module directory as its cwd, otherwise it
      -- can't see the module's .tflint.hcl or its provider config.
      local tflint = lint.linters.tflint
      tflint.cmd = vim.fn.stdpath("data") .. "/mason/bin/tflint"

      local group = vim.api.nvim_create_augroup("nvim-lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
        group = group,
        callback = function()
          -- try_lint silently skips filetypes with no configured linter
          require("lint").try_lint()
        end,
      })
    end,
  },
}
