local ngu = require 'utils.nginx'
local log = require 'utils.log'

local m = {}
m._VERSION = "0.0.1"

m.dicts = {
  active = ngx.shared.plugin_active,
  config = ngx.shared.plugin_config,
  log = ngx.shared.plugin_log,
  errors = ngx.shared.plugin_errors,
  executions = ngx.shared.plugin_executions
}

function m.plugin_active(p)
  local d = m.dicts.active:get_keys()
  if not d[p] then
    return false
  else
    return true
  end
end

function m.find_plugin_for(text)
  local matches = {}
  local active_plugins = m.dicts.active:get_keys()
  if not active_plugins then
    return nil
  else
    for _, k in ipairs(active_plugins) do
      local plugin = m.safe_plugin_load(k)
      if plugin then
        local m, err = ngx.re.match(text, "^"..plugin.regex, 'jo')
        if m then
          -- return the plugin function itself to save another safeload call
          table.insert(matches, plugin)
        end
      end
    end
  end
  return matches
end

function m.generate_id()
  local worker_id = ngx.worker.pid()
  local tstamp = ngx.time()
  return worker_id..tstamp
end

function m.pass_test(...)
  local args = ...
  local resp = {
    passed = true
  }
  if args then
    for k, v in pairs(args) do
      resp[k] = v
    end
  end
  return resp
end

function m.fail_test(msg, ...)
  local args = ...
  local resp = {
    passed = false,
    failure = msg
  }
  if args then
    for k, v in pairs(args) do
      resp[k] = v
    end
  end
  return resp
end

function m.plugin_error(p, msg)
  local plugin_log = m.dicts.log
  local plugin_errors = m.dicts.errors
  local success = m.safe_incr(plugin_errors, p)
  if not success then
    log.warn("Unable to increment counter")
  end
  log.err("Plugin errored with message: ", msg)
  ngx.status = ngx.HTTP_NOT_ALLOWED
  ngx.header.content_type = "application/json"
  ngx.say(safe_json_encode({err = true, msg = msg}))
  ngx.exit(ngx.HTTP_NOT_ALLOWED)
end

function m.get_botname()
  local shared_dict = ngx.shared.ng_shared_dict
  local botname, err = shared_dict:get("bot_name")
  if not botname then
    return "lubot"
  else
    return botname
  end
end

function m.safe_incr(dict, key)
  local d = dict
  local success, err, forcible = d:add(key, 0)
  if not success and err ~= "exists" then
    return nil
  end
  local isuccess, ierror, iforcible = d:incr(key, 1)
  if not isuccess then return nil end
  if ierror then return nil end
  return true
end

function m.safe_plugin_load(p)
  local plugin_ok, plugin = pcall(require, "lubot_"..p)
  if not plugin_ok then
    log.err("Unable to load the plugin: ", p)
    return nil
  else
    if not plugin.id or not plugin.version or not plugin.regex then
      log.err("Plugin missing required metadata (id, version or regex): ", plugin.id)
      return nil
    else
      return plugin
    end
  end
end

function m.safe_plugin_run(p, d)
  local plugin = m.safe_plugin_load(p)
  if not plugin then return m.plugin_error(p, "Plugin failed to load cleanly. Check logs for errors") end
  local run_ok, res, err = pcall(plugin.run, d)
  if not run_ok then return m.plugin_error(p, "Plugin did not run safely: "..res) end
  if err then return m.plugin_error(p, "Plugin returned an error: "..err) end
  local incr_exec = m.safe_incr(m.dicts.executions, p)
  if not incr_exec then log.warn("Unable to increment execution counter for "..p) end
  return res
end

function m.respond_as_json(t)
  ngx.header.content_type = "application/json"
  local response = safe_json_encode(t)
  if not response then
    log.alert("JSON encode failed: ", response)
  else
    ngx.say(response)
    ngx.exit(ngx.HTTP_OK)
  end
end

function m.plugin_help(p)
  local plugin = m.safe_plugin_load(p)
  if not plugin.help then
    local resp = [[Plugin has no help. Displaying regex used instead.
    regex:  `^]]..plugin.regex.."`"
    log.warn("plugin ", plugin.id, " has no help output")
    return resp
  else
    local help_ok, help = pcall(plugin.help)
    if not help_ok then
      m.plugin_error(plugin.id, " help errored: ", help)
    else
      return help
    end
  end
end

function m.plugin_test(p, body)
  local d = body or {}
  local plugin = m.safe_plugin_load(p)
  if not plugin.test then
    m.plugin_error(plugin.id, "No test defined for plugin "..plugin.id)
  else
    local str = d.text
    if str then
      local regex = [=[(^]=]..m.get_botname()..[=[)\s+(?<remainder>.*$)]=]
      local b, e = ngx.re.match(d.text, regex, 'jo')
      if b and b.remainder then
        str = b.remainder
      end
      d.text = str
    end
    local test_ok, test = pcall(plugin.test, d)
    if not test_ok then
      return m.fail_test("Test failed to run: "..test)
    else
      return test
    end
  end
end

function m.plugin_stats(p)
  local resp
  local plugin_errors = ngx.shared.plugin_errors
  local plugin_executions = ngx.shared.plugin_executions
  local plugin_logs = ngx.shared.plugin_logs
  local errcount, err = plugin_errors:get(p)
  if not errcount then
    resp = {plugin = p, errors = 0, msg = err}
  else
    resp = {plugin = p, errors = errcount}
  end
  local excount, exerr = plugin_executions:get(p)
  if not excount then
    resp.executions = 0
  else
    resp.executions = excount
  end
  return resp
end

function m.plugin_details(p)
  local plugin = m.safe_plugin_load(p)
  if not plugin then
    return m.plugin_error(p, "Plugin details not found for "..p)
  else
    local t = {
      version = plugin.version,
      id = plugin.id,
      regex = plugin.regex
    }
    return t
  end
end

function m.enable_plugin(p)
  local success, err, forcible = m.dicts.active:set(p, true)
  if not success and err ~= "exists" then
    return nil, "Plugin already exists"
  elseif forcible then
    return true, "An existing plugin was evicted to make room. This could be bad"
  else
    return true, nil
  end
end

function m.disable_plugin(p)
  m.dicts.active:delete(p)
end

function m.get_active()
  return m.dicts.active:get_keys()
end

function m.load_config()
  local inspect = require 'inspect'

  local defaults = '{"enabled":["status","ping","image","plugins","help"]}'
  local lubot_config = ngx.shared.lubot_config
  local plugin_config_file = lubot_config:get("config_file")
  local config
  if not plugin_config_file then
    log.err("Missing config file, loading defaults")
    config = safe_json_decode(defaults)
  else
    log.alert("Loading config from ", plugin_config_file)
    local file = io.open(plugin_config_file)
    if not file then
      log.err("Unable to read file. Loading defaults")
      config = safe_json_decode(defaults)
    else
      local content = file:read("*a")
      file:close()
      config = safe_json_decode(content)
    end
  end
  for idx, plugin in pairs(config.enabled) do
    log.alert("Enabling plugin: ", plugin)
    m.dicts.active:set(plugin, true)
    if config[plugin] then
      local plugin_settings = safe_json_encode(config[plugin])
      m.dicts.config:set(plugin, plugin_settings)
      log.alert("Loading ", plugin, " settings from config: ", inspect(config[plugin]))
    end
  end
  return config
end

function m.pick_random(t)
  math.randomseed(ngx.time())
  local candidates = t
  return candidates[math.random(#candidates)]
end

function m.match(...)
  local s, err = ngx.re.match(unpack({...}), 'jo')
end
return m
