local notify = require("cfn.lib.notify")
local store = require("cfn.lib.state.store")

---@class Map<T>
---@field data table<string, T>
---@field callbacks fun(key: string, value: T?)[]
---@field on_change fun(self, callback: fun(key: string, value: T?))
---@field set fun(self, key: string, value: T?)
---@field get fun(self, key: string): T?
---@field list fun(self): table<string, T>
---@field remove fun(self, key: string)
local Map = {}

Map.__index = Map

---@generic T
---@return Map<T>
function Map.new()
  local self = setmetatable({}, Map)
  self.data = {}
  self.callbacks = {}
  return self
end

function Map:on_change(callback)
  table.insert(self.callbacks, callback)
end

function Map:get(key)
  return self.data[key]
end

function Map:set(key, value)
  self.data[key] = value
  for _, callback in ipairs(self.callbacks) do
    callback(key, value)
  end
end

function Map:list()
  return self.data
end

function Map:remove(key)
  self.data[key] = nil
  for _, callback in ipairs(self.callbacks) do
    callback(key, nil)
  end
end

---@param filename string
function Map:persist(filename)
  local store_dir = store.get_store_dir()
  local path = vim.fs.joinpath(store_dir, filename)

  -- load existing data
  local readf, readf_err = io.open(path, "r")
  if readf_err == nil and readf ~= nil then
    local read_data, read_err = readf:read("*a")
    if read_err == nil and read_data ~= nil then
      local ok, parsed_read_data = pcall(vim.json.decode, read_data)
      if ok then
        self.data = parsed_read_data
      end
    end
    readf:close()
  end

  -- set notification hook to save on change
  self:on_change(function(_, _)
    local data = self:list()
    local encoded = vim.json.encode(data, {
      indent = "  ",
    })
    local writef, writef_err = io.open(path, "w")
    if writef_err ~= nil then
      notify.error("failed to open store dir: " .. writef_err)
      return
    elseif writef == nil then
      notify.error("failed to open store dir: file object is nil")
      return
    end
    local _, write_err = writef:write(encoded)
    writef:close()
    if write_err ~= nil then
      notify.error("failed to save template registrations: " .. write_err)
      return
    end
  end)
end

return Map
