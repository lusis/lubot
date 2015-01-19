local id = "ping"
local version = "0.0.1"
local regex = [[ping]]
local p = require 'utils.plugins'
local slack = require 'utils.slack'

local function run(data)
  local tstamp = ngx.now()

  local text = "pong ["..tstamp.."]"
  return slack.say(text) 
end

local function test(data)
  local res = run(data)
  local expects = [=[^pong .*$]=]
  local params = {
    mock_data = data,
    expects = expects,
    run_data = res
  }
  local t = require('utils.test').new(params)
  t:add("responds_text")
  t:add("response_contains")
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
