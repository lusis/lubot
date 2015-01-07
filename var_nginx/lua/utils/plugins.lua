local ngu = require 'utils.nginx'
local m = {}

m.dicts = {
  active = ngx.shared.plugin_active,
  config = ngx.shared.plugin_config,
  log = ngx.shared.plugin_log,
  errors = ngx.shared.plugin_errors,
  executions = ngx.shared.plugin_executions
}

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
    ngu.logwarn("Unable to increment counter")
  end
  ngu.logerr("Plugin errored with message: ", msg)
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
    ngu.logerr("Unable to load the plugin: ", p)
    return nil
  else
    if not plugin.id or not plugin.version or not plugin.regex then
      ngu.logerr("Plugin missing required metadata (id, version or regex): ", plugin.id)
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
  if not incr_exec then ngu.logwarn("Unable to increment execution counter for "..p) end
  return res
end

function m.respond_as_json(t)
  ngx.header.content_type = "application/json"
  local response = safe_json_encode(t)
  ngx.say(response)
  ngx.exit(ngx.HTTP_OK)
end

function m.plugin_test(p, d)
  local plugin = m.safe_plugin_load(p)
  if not plugin.test then
    m.plugin_error(plugin.id, "No test defined for plugin "..plugin.id)
  else
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

  local defaults = '{"enabled":["status","ping","image"]}'
  local lubot_config = ngx.shared.lubot_config
  local plugin_config_file = lubot_config:get("config_file")
  local config
  if not plugin_config_file then
    ngu.logerr("Missing config file, loading defaults")
    config = safe_json_decode(defaults)
  else
    ngu.loginfo("Loading config from ", plugin_config_file)
    local file = io.open(plugin_config_file)
    if not file then
      ngu.logerr("Unable to read file. Loading defaults")
      config = safe_json_decode(defaults)
    else
      local content = file:read("*a")
      file:close()
      config = safe_json_decode(content)
    end
  end
  for idx, plugin in pairs(config.enabled) do
    ngu.loginfo("Enabling plugin: ", plugin)
    m.dicts.active:set(plugin, true)
    if config[plugin] then
      local plugin_settings = safe_json_encode(config[plugin])
      m.dicts.config:set(plugin, plugin_settings)
      ngu.loginfo("Loading ", plugin, " settings from config: ", inspect(config[plugin]))
    end
  end
  return config
end

return m
