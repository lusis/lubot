_plugin = {}

_plugin.id = "plugins"
_plugin.version = "0.0.1"
_plugin.regex = [=[(plugins|plugin) (?<plugin_action>(enable|disable|list|stats))?\s?(?<plugin_name>\w+)?$]=]
local p = require 'utils.plugins'
local chat = require 'utils.slack'
local ngu = require 'utils.nginx'
local log = require 'utils.log'

local function process_action(...)
  local args = ...
  if args.plugin_action == "list" then
    local active = p.get_active()
    return "active plugins: "..table.concat(active, " | ")
  end
  if args.plugin_action == "stats" then
    if not args.plugin_name then
      return "Missing plugin name"
    else
      if args.plugin_name == "all" then
        local errors = 0
        local executions = 0
        local active = p.get_active()
        for _, v in ipairs(active) do
          local stats = p.plugin_stats(v)
          if stats then
            errors = errors + stats.errors
            executions = executions + stats.executions
          end
        end
        return "stats for all plugins: errors = "..errors.." | executions = "..executions
      else
        local stats = p.plugin_stats(args.plugin_name)
        if not stats then
          return "no stats for "..args.plugin_name
        else
          local s = {}
          for k,v in pairs(stats) do if k ~= "plugin" then table.insert(s, k.."="..v) end end
          return "stats for plugin '"..stats.plugin.."': "..table.concat(s, " | ")
        end
      end
    end
  end
  if args.plugin_action == "disable" then
    if not args.plugin_name then
      return "Missing plugin name"
    end
    if args.plugin_name == _plugin.id then
      return "You can't disable this plugin this way"
    end
    p.disable_plugin(args.plugin_name)
    return "Disabled plugin"..args.plugin_name
  end
  if args.plugin_action == "enable" then
    if not args.plugin_name then
      return "Missing plugin name"
    end
    local active = p.get_active()

    if args.plugin_name == _plugin.id or active[args.plugin_name] then
      return "plugin already active"
    end
    local enable, err = p.enable_plugin(args.plugin_name)
    if not enable then
      if err then return err end
    end
    return "Enabled plugin "..args.plugin_name
  end
end

function _plugin.run(data)
  if not data.text then
    return nil, "Missing message text"
  end
  local m, err = ngx.re.match(data.text, _plugin.regex, 'jo')
  if not m then
    return nil, "Unable to match '"..data.text.."' to '".._plugin.regex.."'"
  else
    if not m.plugin_action then
      return nil, "Unable to find an action to take"
    end
    local resp = process_action(m)
    return chat.say(resp)
  end
end

function _plugin.help()
  local h = [[
  <botname> plugins enable <plugin>: enables the specified plugin
  <botname> plugins disable <plugin>: disabled the specified plugin
  <botname> plugins list: lists all active plugins
  <botname> plugins stats <all|plugin name>: returns cumulative stats for all plugins or just the specified plugin
  ]]
  return h
end

function _plugin.test(...)
  -- use our own data here
  local data = {user = "foo", channel = "bar", text = "plugin stats ping"}
  local res, err = _plugin.run(data)
  local params = {
    mock_data = data,
    run_data = res
  }
  local t = require('utils.test').new(params)
  t:add("responds_text")
  t:add("response_contains", [=[(^stats for plugin '\w+': errors=\d+ | executions=\d+)$]=])
  t:run()
  return t:report()
end

return _plugin
