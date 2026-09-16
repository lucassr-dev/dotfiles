-- ══════════════════════════════════════════════════════════════════════════════
-- TESTES
--
-- O extra test.core traz o neotest sem adapter. Estes sao os frameworks em uso
-- nos repositorios: Vitest e Jest.
-- ══════════════════════════════════════════════════════════════════════════════

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-jest",
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}

      -- tests/ e o testDir do Playwright (playwright.config.ts), nao do Vitest. Sem
      -- este filtro o neotest-vitest reivindica specs do Playwright pelo nome
      -- (*.spec.ts) e o <leader>tt roda vitest num arquivo que ele nao sabe testar.
      local vitest_adapter = require("neotest-vitest")
      local vitest_is_test_file = vitest_adapter.is_test_file
      table.insert(
        opts.adapters,
        vitest_adapter({
          filter_dir = function(name, _relpath, _root)
            return name ~= "node_modules" and name ~= "tests"
          end,
          is_test_file = function(file_path)
            if file_path:match("/tests/") then
              return false
            end
            return vitest_is_test_file(file_path)
          end,
        })
      )
      table.insert(
        opts.adapters,
        require("neotest-jest")({
          jestCommand = "npm test --",
          env = { CI = true },
          cwd = function()
            return vim.fn.getcwd()
          end,
        })
      )
    end,
  },
}
