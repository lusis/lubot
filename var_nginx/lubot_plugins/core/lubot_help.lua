_plugin = {}

_plugin.id = "help"
_plugin.version = "0.0.1"
_plugin.regex = [=[help\s?(?<plugin_name>\w+)?$]=]
local p = require 'utils.plugins'
local chat = require 'utils.slack'
local ngu = require 'utils.nginx'
local log = require 'utils.log'

function _plugin.run(data)
  if not data.text then
    return nil, "Missing message text"
  end
  local m, err = ngx.re.match(data.text, _plugin.regex, 'jo')
  if not m then
    return nil, "Unable to match '"..data.text.."' to '".._plugin.regex.."'"
  else
    if not m.plugin_name then
      return chat.say(_plugin.help())
    else
      return chat.say(p.plugin_help(m.plugin_name))
    end
  end
end

function _plugin.help()
  local h = [[
  <botname> help <plugin>: Displays help for a given plugin
  ]]
  return h
end

function _plugin.test(...)
  -- use our own data here
  local data = {user = "foo", channel = "bar", text = "plugin help help"}
  local res, err = _plugin.run(data)
  local params = {
    mock_data = data,
    run_data = res
  }
  local t = require('utils.test').new(params)
  t:add("responds_text")
  t:add("response_contains", "Displays help for a given plugin")
  t:run()
  return t:report()
end

return _plugin
