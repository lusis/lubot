local id = "image"
local version = "0.0.1"
local regex = [=[^\w+ (image|img)( me)? (?<search_string>.*)$]=]
local p = require 'utils.plugins'
local slack = require 'utils.slack'

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
    return candidates[math.random(#candidates)].unescapedUrl
  end
end

local function match(str)
  local m, err = ngx.re.match(str, regex, 'jo')
  if not m then
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
    return nil, "Missing string to search for"
  else
    local img = query_google(m)
    if not img then
      return nil, "No image found"
    end
    resp = slack.to_rts_message(img, data.channel)
    return resp
  end
end

local function test(data)
  local resp = {}
  if not data.text or not data.expects then
    return p.fail_test("missing message text or expectation")
  end
  local m = match(data.text)
  if m ~= data.expects then
    return p.fail_test("expected did not match", {expected = data.expects, match = m})
  else
    resp.expected = data.expects
    resp.got = m
    local res = run(data)
    if not res then
      return p.fail("pattern match test passed but plugin returned no results")
    else
      resp.results = res.text
    end
    return p.pass_test(resp)
  end
end

local plugin = {
  run = run,
  id = id,
  version = version,
  regex = regex,
  test = test
}

return plugin
