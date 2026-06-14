local util = require("cmp_dictionary.util")

---@class cmp.dictionary.dict.external: cmp.dictionary.dict
---@field command string[]
---@field paths string[]
local M = {}

---@param command string[]
---@return cmp.dictionary.dict.external
function M.new(command)
  return setmetatable({
    command = command,
    paths = {},
  }, { __index = M })
end

---@param paths string[]
function M:update(paths)
  self.paths = paths
end

---@param prefix string
---@return lsp.CompletionItem[]
function M:search(prefix, callback)
  prefix = vim.fn.tolower(prefix)
  local items = {}
  for _, path in ipairs(self.paths) do
    local command = vim.tbl_map(function(c)
      return c:gsub("${prefix}", prefix):gsub("${path}", path)
    end, self.command)
    local info = string.format("belong to `%s`", vim.fn.fnamemodify(path, ":t"))
    vim.system(
      { "sh", "-c", "cat /usr/share/dict/words | fzf --filter '" .. prefix .. "' | head -n 5" },
      { text = true },
      function(result)
        local output = vim.split(result.stdout or "", "\n")
        for _, word in ipairs(output) do
          if word ~= "" then
            table.insert(items, { kind = 24, label = word, info = info })
          end
        end
        callback(items)
      end
    )
  end
  return items
end

return M
