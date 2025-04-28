local M = {}

---@class LRUCache
---@field capacity number Maximum number of items in the cache
---@field cache table Internal storage for cache items
---@field access_order table Tracking order of item access
local LRUCache = {}
LRUCache.__index = LRUCache

--- Create a new LRU Cache
---@param capacity number Maximum number of items to store in the cache
---@return LRUCache
function M.new(capacity)
  local self = setmetatable({}, LRUCache)
  self.capacity = capacity or 100 -- Default capacity of 100 items
  self.cache = {} -- Stores the actual key-value pairs
  self.access_order = {} -- Tracks the order of access for each key
  return self
end

--- Get an item from the cache
---@param key any The key to retrieve
---@return any|nil The value associated with the key, or nil if not found
function LRUCache:_get(key)
  -- Check if the key exists
  if not self.cache[key] then
    return nil
  end

  -- Update the access order
  self:_touch(key)

  return self.cache[key]
end

--- Set an item in the cache
---@param ctx table The local context
---@param value any The value to associate with the key
function LRUCache:add(ctx, value)
  local local_context = ctx.prefix .. "Î" .. ctx.middle .. "Î" .. ctx.suffix
  local hash = vim.fn.sha256(local_context)
  self:_set(hash, value)
end

--- Set an item in the cache
---@param key any The key to store
---@param value any The value to associate with the key
function LRUCache:_set(key, value)
  -- If key already exists, update its value and move to most recently used
  if self.cache[key] then
    self.cache[key] = value
    self:_touch(key)
    return
  end

  -- If cache is at capacity, remove the least recently used item
  if #self.access_order >= self.capacity then
    local lru_key = table.remove(self.access_order, 1)
    self.cache[lru_key] = nil
  end

  -- Add new item
  self.cache[key] = value
  table.insert(self.access_order, key)
end

--- Remove an item from the cache
---@param key any The key to remove
function LRUCache:remove(key)
  if not self.cache[key] then
    return
  end

  -- Remove from cache
  self.cache[key] = nil

  -- Remove from access order
  for i, k in ipairs(self.access_order) do
    if k == key then
      table.remove(self.access_order, i)
      break
    end
  end
end

--- Touch a key to mark it as most recently used
---@param key any The key to touch
function LRUCache:_touch(key)
  -- Remove the key from its current position
  for i, k in ipairs(self.access_order) do
    if k == key then
      table.remove(self.access_order, i)
      break
    end
  end

  -- Add to the end (most recently used)
  table.insert(self.access_order, key)
end

--- Get the current number of items in the cache
---@return number
function LRUCache:size()
  return #self.access_order
end

--- Clear the entire cache
function LRUCache:clear()
  self.cache = {}
  self.access_order = {}
end

--- Check for cached completion
---@param ctx table context
---@return table|nil Cached completion or nil
function LRUCache:get_cached_completion(ctx)
  local local_context = ctx.prefix .. "Î" .. ctx.middle .. "Î" .. ctx.suffix
  local hash = vim.fn.sha256(local_context)
  local cached_completion = self:_get(hash)

  -- If direct hash not found, try nearby cached completions
  if not cached_completion then
    for i = 1, 10 do
      -- Try removing last i characters from past text
      local past_text = ctx.prefix .. "Î" .. ctx.middle
      local removed_section = past_text:sub(-i)
      local hash_txt = past_text:sub(1, -(2 + i)) .. "Î" .. ctx.suffix
      local temp_hash = vim.fn.sha256(hash_txt)

      local temp_cached_content = self:_get(temp_hash)

      if temp_cached_content then
        -- Check if the cached content matches the removed section
        if temp_cached_content == "" then
          break
        end

        if temp_cached_content:sub(1, i) ~= removed_section then
          break
        end

        -- Extract the relevant part of the cached content
        local response_content = temp_cached_content:sub(i + 1)
        self:_set(temp_hash, response_content)

        return response_content
      end
    end
  end

  return cached_completion
end

return M
