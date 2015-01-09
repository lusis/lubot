local id = "image"
local version = "0.0.1"
local regex = [=[(image|img)( me)? (?<search_string>.*)$]=]

local p = require 'utils.plugins'
local slack = require 'utils.slack'
local ngu = require 'utils.nginx'
local log = require 'utils.log'

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

    local b = safe_json_decode(res.body)
    if not b then return nil end
    local candidates = b.responseData.results
    return p.pick_random(candidates).unescapedUrl
  end
end

local function match(str)
  local m, err = ngx.re.match(str, regex, 'jo')
  if not m then
    log.err(err or "No match for "..str)
    return nil
  else
    return m['search_string']
  end
end

local function run(data)
  if not data.text then
    return nil, "Missing message text"
  end
  local m = match(data.text)
  if not m then
    log.err("Missing string to search for")
    return nil, "Missing string to search for"
  else
    local img = query_google(m)
    if not img then
      log.err("No image found")
      return nil, "No image found"
    end
    return slack.say(img)
  end
end

local function test(data)
  local res = run(data)
  -- response should be a url
  local expects = [=[^http.*$]=]
  local params = {
    mock_data = data,
    run_data = res
  }
  local t = require('utils.test').new(params)
  -- basic tests
  t:add("responds_text")
  t:add("response_contains", expects)
  t:add("parses_text", regex, 'search_string')
  t:add("captures_value", data.expects, regex, 'search_string')
  t:run()
  return t:report()
end

local plugin = {
  run = run,
  id = id,
  version = version,
  regex = regex,
  test = test
}

return plugin
