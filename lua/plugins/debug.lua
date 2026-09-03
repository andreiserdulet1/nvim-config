-- Debugging Angular in Chrome.
--
-- Everything here is lazy: nothing loads until you press a <leader>d key, so
-- startup is unaffected if you never debug.
--
-- How it works: the Angular dev server (`yarn start`, or <leader>ns) serves your
-- app with source maps. js-debug drives a Chrome instance, maps the running
-- bundle back to your .ts files, and stops on breakpoints you set in the editor.
return {

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        opts = {
          layouts = {
            {
              elements = {
                { id = "scopes", size = 0.35 },
                { id = "breakpoints", size = 0.15 },
                { id = "stacks", size = 0.25 },
                { id = "watches", size = 0.25 },
              },
              size = 44,
              position = "left",
            },
            {
              elements = { { id = "repl", size = 0.5 }, { id = "console", size = 0.5 } },
              size = 10,
              position = "bottom",
            },
          },
        },
      },
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = { virt_text_pos = "eol", commented = true },
      },
    },

    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      {
        "<leader>dB",
        function()
          vim.ui.input({ prompt = "Break when: " }, function(cond)
            if cond and cond ~= "" then require("dap").set_breakpoint(cond) end
          end)
        end,
        desc = "Conditional breakpoint",
      },
      { "<leader>dc", function() require("dap").continue() end, desc = "Start / continue" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "Re-run last config" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle debug UI" },
      {
        "<leader>dt",
        function()
          require("dap").terminate()
          require("dapui").close()
        end,
        desc = "Terminate session",
      },
      { "<leader>dw", function() require("dapui").elements.watches.add(vim.fn.expand("<cexpr>")) end,
        desc = "Watch expression under cursor" },
    },

    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- Breakpoint signs, using the theme's own colours.
      vim.fn.sign_define("DapBreakpoint",
        { text = "●", texthl = "DiagnosticError", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition",
        { text = "◆", texthl = "DiagnosticWarn", numhl = "" })
      vim.fn.sign_define("DapStopped",
        { text = "▶", texthl = "DiagnosticInfo", linehl = "Visual", numhl = "" })
      vim.fn.sign_define("DapBreakpointRejected",
        { text = "○", texthl = "Comment", numhl = "" })

      -- Open the panels with the session and close them when it ends.
      dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"] = function() dapui.close() end

      -- The adapter, installed by Mason (see ensure_installed in lsp.lua).
      dap.adapters["pwa-chrome"] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/bin/js-debug-adapter",
          args = { "${port}" },
        },
      }

      -- Project root, recomputed per session so this follows you between repos.
      local function web_root()
        return vim.fs.root(0, { "angular.json", "package.json", ".git" }) or vim.uv.cwd()
      end

      -- Angular 17+ serves through esbuild/Vite, whose source-map URLs don't
      -- line up with the workspace by default. These overrides are what let a
      -- breakpoint in src/app/**/*.ts actually bind to the running bundle.
      local source_map_overrides = {
        ["webpack:///./*"] = "${webRoot}/*",
        ["webpack:///src/*"] = "${webRoot}/src/*",
        ["webpack://_N_E/*"] = "${webRoot}/*",
        ["webpack://?:*/*"] = "${webRoot}/*",
        ["/./*"] = "${webRoot}/*",
        ["/src/*"] = "${webRoot}/src/*",
        ["/*"] = "*",
        ["/@fs/*"] = "*",
      }

      local configurations = {
        {
          type = "pwa-chrome",
          request = "launch",
          name = "Angular: launch Chrome on the dev server",
          url = function()
            return coroutine.create(function(co)
              vim.ui.input({ prompt = "Dev server URL: ", default = "http://localhost:4200" },
                function(url)
                  coroutine.resume(co, url or "http://localhost:4200")
                end)
            end)
          end,
          webRoot = web_root,
          sourceMaps = true,
          sourceMapPathOverrides = source_map_overrides,
          -- A separate profile dir keeps your normal Chrome session untouched.
          userDataDir = vim.fn.stdpath("cache") .. "/dap-chrome",
        },
        {
          type = "pwa-chrome",
          request = "attach",
          name = "Angular: attach to Chrome on :9222",
          port = 9222,
          webRoot = web_root,
          sourceMaps = true,
          sourceMapPathOverrides = source_map_overrides,
        },
      }

      for _, ft in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
        dap.configurations[ft] = configurations
      end
    end,
  },
}
