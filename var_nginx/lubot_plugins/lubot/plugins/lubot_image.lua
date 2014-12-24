local id = "lubot-image"
local version = "0.0.1"
local regex = [[^\w+ image me (.*)$]]

local function query_google(str)
  local gurl = "http://ajax.googleapis.com/ajax/services/search/images"
  local params = {
    v = "1.0",
    rsz = "8",
    q = str,
    safe = "active"
  }
  local cjson = require 'cjson'
  local hc = require("httpclient").new('httpclient.ngx_driver')
  local res = hc:get(gurl, {params = params})
  if res.err then
    return nil
  else
    math.randomseed(ngx.time())
    local b = cjson.decode(res.body)
    local candidates = b.responseData.results
    ngx.log(ngx.INFO, "Number of candidates: ", #candidates)
    return candidates[math.random(#candidates)].unescapedUrl
  end
end

local function run(data)
  local worker_id = ngx.worker.pid()
  local tstamp = ngx.time()

  local resp = {
    ["type"] = "message",
    channel = data.channel,
    id = worker_id..tstamp
  }

  if not data.text then
    return nil, "Missing message text"
  end
  local m, err = ngx.re.match(data.text, regex, 'jo')
  if not m then
    return nil, "Missing string to search for"
  else
    local img = query_google(m[1])
    if not img then
      return nil, "No image found"
    end
    resp.text = img
    return resp
  end
end

local plugin = {
  run = run,
  id = id,
  version = version
}

return plugin
