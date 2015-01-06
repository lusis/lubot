local id = "ping"
local version = "0.0.1"
local regex = [[ping]]
local p = require 'utils.plugins'
local slack = require 'utils.slack'

local function run(data)
  local tstamp = ngx.time()

  local text = "pong ("..tstamp..")"
  return slack.to_rts_message(text, data.channel) 
end

local function test(data)
  local res = run(data)
  local expects = [=[^pong .*$]=]

  if type(res) ~= 'table' then return p.fail_test("not a table") end
  if not res.text then return p.fail_test("missing response text") end
  local m, err = ngx.re.match(res.text, expects)
  if not m then return p.fail_test("no "..expects.." in text") end
  if res.channel ~= data.channel then return p.fail_test("channel mismatch") end
  return p.pass_test({expected = expects, got = m[0]})
end

local plugin = {
  run = run,
  id = id,
  version = version,
  regex = regex,
  test = test
}

return plugin
