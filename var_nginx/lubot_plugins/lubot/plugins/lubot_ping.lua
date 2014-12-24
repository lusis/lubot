local id = "lubot-ping"
local version = "0.0.1"
local function run(data)
  local worker_id = ngx.worker.pid()
  local tstamp = ngx.time()

  local resp = {
    ["type"] = "message",
    channel = data.channel,
    id = worker_id..tstamp
  }

  resp.text = "pong ("..tstamp..")"
  return resp
end

local plugin = {
  run = run,
  id = id,
  version = version
}

return plugin
