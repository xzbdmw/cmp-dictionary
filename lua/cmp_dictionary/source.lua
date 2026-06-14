local config = require("cmp_dictionary.config")
local Dict = require("cmp_dictionary.dict")
local util = require("cmp_dictionary.util")

---@class cmp.Source.dictionary: cmp.Source
---@field dict cmp.dictionary.dict
local source = {}
source.__index = source

function source.new()
  local self = setmetatable({}, source)
  self.dict = Dict.new()
  self:_update()
  return self
end

function source.get_keyword_pattern()
  return [[\k\+]]
end

---@param x unknown
---@return boolean
local function Boolean(x)
  return not not x
end

---@param str string
---@return boolean
local function is_capital(str)
  return Boolean(str:find("^%u"))
end

---@param str string
---@return string
local function capitalize(str)
  local u = str:gsub("^%l", string.upper)
  return u
end

---@param str string
---@return string
local function decapitalize(str)
  local l = str:gsub("^%u", string.lower)
  return l
end

function source:_update()
  local opts = config.options
  self.dict:update(opts.paths)
end

---@param request cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionList) sunch
function source:complete(request, callback)
  local enable = false
  if
    require("cmp.config.context").in_treesitter_capture("comment")
    or require("cmp.config.context").in_treesitter_capture("string")
    or request.context.option.reason == "manual"
    or vim.bo.filetype == "gitcommit"
  then
    enable = true
  end
  if not enable then
    callback({})
    return
  end
  local opts = config.options
  local req = request.context.cursor_before_line:sub(request.offset)
  local isIncomplete = false
  if opts.exact_length > 0 then
    req = req:sub(1, opts.exact_length)
    isIncomplete = #req < opts.exact_length
  end

  -- Calls by cmp.complete ignore the keyword_length. synch
  if request.keyword_length and #req < request.keyword_length then
    callback({ items = {}, isIncomplete = true })
    return
  end

  local function call(items)
    if opts.max_number_items > 0 and #items > opts.max_number_items then
      items = vim.list_slice(items, 1, opts.max_number_items)
    end
    callback({ items = items, isIncomplete = true })
  end
  local items
  if opts.first_case_insensitive then
    if is_capital(req) then
      items = vim.list_extend(
        self.dict:search(req),
        vim.tbl_map(function(item)
          item.label = capitalize(item.label)
          return item
        end, self.dict:search(decapitalize(req), call))
      )
    else
      items = vim.list_extend(
        self.dict:search(req),
        vim.tbl_map(function(item)
          item.label = decapitalize(item.label)
          return item
        end, self.dict:search(capitalize(req), call))
      )
    end
  else
    items = self.dict:search(req, call)
  end
  if opts.max_number_items > 0 and #items > opts.max_number_items then
    items = vim.list_slice(items, 1, opts.max_number_items)
  end

  callback({ items = items, isIncomplete = true })
end

---@param item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source.resolve(_, item, callback)
  local opts = config.options
  if item.documentation == nil and opts.document.enable then
    local command = vim.tbl_map(function(c)
      return c:gsub("${label}", item.label)
    end, opts.document.command)
    local result = util.system(command)
    item.documentation = table.concat(result, "\n")
  end
  callback(item)
end

return source
