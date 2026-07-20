-- Debugging with nvim-dap, using LLVM's bundled lldb-dap (no extra install).
-- Compile with -g first (F5 already does), then start the debugger.
return {
  "mfussenegger/nvim-dap",
  dependencies = {
    { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
    "theHamsta/nvim-dap-virtual-text",
  },
  keys = {
    { "<F9>", function() require("dap").toggle_breakpoint() end, desc = "DAP: breakpoint" },
    { "<F10>", function() require("dap").step_over() end, desc = "DAP: step over" },
    { "<F11>", function() require("dap").step_into() end, desc = "DAP: step into" },
    { "<F12>", function() require("dap").step_out() end, desc = "DAP: step out" },
    { "<leader>dc", function() require("dap").continue() end, desc = "DAP: continue/start" },
    { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "DAP: breakpoint" },
    {
      "<leader>dB",
      function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end,
      desc = "DAP: conditional breakpoint",
    },
    { "<leader>dr", function() require("dap").repl.toggle() end, desc = "DAP: REPL" },
    { "<leader>dl", function() require("dap").run_last() end, desc = "DAP: run last" },
    { "<leader>dt", function() require("dap").terminate() end, desc = "DAP: terminate" },
    { "<leader>du", function() require("dapui").toggle() end, desc = "DAP: toggle UI" },
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    dapui.setup()
    require("nvim-dap-virtual-text").setup()

    -- Breakpoint signs
    vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticSignError" })
    vim.fn.sign_define("DapStopped", { text = "", texthl = "DiagnosticSignWarn", linehl = "Visual" })

    -- lldb-dap adapter (ships with LLVM)
    dap.adapters.lldb = {
      type = "executable",
      command = "C:\\Program Files\\LLVM\\bin\\lldb-dap.exe",
      name = "lldb",
    }

    local cpp_config = {
      {
        name = "Launch current file",
        type = "lldb",
        request = "launch",
        program = function()
          -- Defaults to the .exe next to the current source (built by F5)
          local default = vim.fn.expand("%:p:r") .. ".exe"
          return vim.fn.input("Path to executable: ", default, "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
      },
    }
    dap.configurations.cpp = cpp_config
    dap.configurations.c = cpp_config

    -- Auto open/close the UI with the session
    dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
    dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
    dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
  end,
}
