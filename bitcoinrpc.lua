--[[
Copyright (c) 2015 James Turner <james@calminferno.net>

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
]]

local M = {
  status = nil,
  error = nil,
  response = nil,
  raw_response = nil
}

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("dkjson")

local config = {
  username = nil,
  password = nil,
  host = "127.0.0.1",
  port = 8332
}
local id = 0;

function M.init(username, password, host, port)
  assert(username ~= nil, "username required")
  assert(password ~= nil, "password required")

  config.username = username
  config.password = password

  if host ~= nil then
    assert(type(host) == "string", "host must be a string")
    config.host = host
  end

  if port ~= nil then
    assert(type(port) == "number", "port must be a number")
    config.port = port
  end
end

function M.call(method, ...)
  local params = {...}
  id = id + 1

  local reqbody = json.encode({
    method = method,
    params = params,
    id = id
  })
  local respbody = {}

  http.TIMEOUT = 5
  local ret, code, headers = http.request({
    url = "http://" .. config.username .. ":" .. config.password .. "@" .. config.host .. ":" .. config.port .. "/",
    headers = {
      ["Content-type"] = "application/json",
      ["Content-length"] = string.len(reqbody)
    },
    method = "POST",
    source = ltn12.source.string(reqbody),
    sink = ltn12.sink.table(respbody)
  })

  if ret == 1 then
    M.status = code
    M.raw_response = table.concat(respbody)
    M.response = json.decode(M.raw_response)
    M.error = nil

    if M.status ~= 200 then
      if M.status == 400 then
        M.error = "HTTP_BAD_REQUEST"
      elseif M.status == 401 then
        M.error = "HTTP_UNAUTHORIZED"
      elseif M.status == 403 then
        M.error = "HTTP_FORBIDDEN"
      elseif M.status == 404 then
        M.error = "HTTP_NOT_FOUND"
      end
    elseif type(M.response.error) == "table" then
      M.error = M.response.error.message
    end

    if M.error ~= nil then
      return nil
    end

    return M.response.result
  else
    M.status = nil
    M.raw_response = nil
    M.response = nil
    M.error = code
    return nil
  end
end

return M
