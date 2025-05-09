local M = {}

---Makes an HTTP POST request using vim.system
---@param url string The URL to make the request to
---@param body string The request body
---@param headers table The request headers
---@param callback function The callback function to handle the response
---@param on_error function The error handler function
---@return number|nil The job ID if successful, nil otherwise
function M.post(url, body, headers, callback, on_error)
  -- Convert headers table to curl format
  local header_args = {}
  for key, value in pairs(headers) do
    table.insert(header_args, "-H")
    table.insert(header_args, key .. ": " .. value)
  end

  -- Prepare curl command arguments
  local args = {
    "curl",
    "-s",
    "-X",
    "POST",
    "-d",
    body,
    url,
    unpack(header_args),
  }

  -- Execute curl command
  local job_id = vim.system(args, { text = true }, function(result)
    if result.code ~= 0 then
      if on_error then
        on_error({ message = result.stderr })
      end
      return
    end

    if callback then
      callback({ body = result.stdout })
    end
  end)

  return job_id
end

return M

