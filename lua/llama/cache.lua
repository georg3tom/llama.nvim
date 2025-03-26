local config = require("llama.config")

local M = {
	data = {},
	max_size = 250,
}

function M.init()
	M.max_size = config.values.max_cache_keys
end

--- @param key string Cache key
--- @param value any Value to cache
function M.insert(key, value)
	if vim.tbl_count(M.data) >= M.max_size then
		-- Remove a random key when cache is full
		local keys = vim.tbl_keys(M.data)
		local random_key = keys[math.random(#keys)]
		M.data[random_key] = nil
	end

	M.data[key] = value
end

--- @param key string Cache key
--- @return any Cached value or nil
function M.get(key)
	return M.data[key]
end

--- @param key string Cache key
--- @return boolean
function M.has(key)
	return M.data[key] ~= nil
end

function M.clear()
	M.data = {}
end

return M
