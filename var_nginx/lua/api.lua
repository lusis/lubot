local _VERSION = "0.0.1"
local router = require 'router'
local ngu = require 'utils.nginx'
local plugutils = require 'utils.plugins'
local log = require 'utils.log'

local r = router.new()

r:get('/_private/api/brain/inspect', function(params)
  local inspect = require('inspect')
  ngx.header.content_type = "text/plain"
  local response = inspect(robot.brain)
  ngx.say(response)
  ngx.exit(ngx.HTTP_OK)
end)

r:get('/_private/api/brain/all', function(params)
  local data = robot.brain:keys()
  if not data then
    log.alert("No data in brain")
    plugutils.respond_as_json({count = 0, msg = "No data found in brain"})
  else
    local t = {}
    for _, k in ipairs(data) do
      local v = robot.brain:get(k)
      if not v then
        --log.alert("Missing data for key ", k)
      else
        t[k] = v
      end
    end
    plugutils.respond_as_json(t)
  end
end)

r:get('/_private/api/brain/:key', function(params)
  local data = robot.brain:get(params.key)
  if not data then return {} end
  local t = {}
  t[params.key] = data
  plugutils.respond_as_json(t)
end)

r:post('/_private/api/plugins/find_match', function(params)
  local data = params.data
  local plugin = plugutils.find_plugin_for(data)
  if not plugin then
    plugutils.respond_as_json({count = 0})
  else
    local results = {}
    for _, k in ipairs(plugin) do table.insert(results, k.id) end
    plugutils.respond_as_json({count = #plugin, results = results})
  end
end)

r:get('/_private/api/plugins/last_error/:plugin_name', function(params)
  local plugin = plugutils.get_last_error(params.plugin_name)
  if not plugin then
    plugutils.respond_as_json({
      msg = "no logs available for plugin "..params.plugin_name
    })
  else
    plugutils.respond_as_json(plugin)
  end
end)

r:get('/_private/api/plugins/logs/:plugin_name', function(params)
  local plugin = plugutils.get_logs(params.plugin_name)
  if not plugin then
    plugutils.respond_as_json({
      msg = "no logs available for plugin "..params.plugin_name
    })
  else
    plugutils.respond_as_json(plugin)
  end
end)

r:get('/_private/api/plugins/help/:plugin_name', function(params)
  local plugin = plugutils.plugin_help(params.plugin_name)
  if not plugin then
    plugutils.respond_as_json({
      msg = "no help available for plugin "..params.plugin_name
    })
  else
    plugutils.respond_as_json({msg = plugin})
  end
end)

r:post('/_private/api/plugins/run/:plugin_name', function(params)
  local data
  if params.data then
    data = safe_json_decode(params.data)
  end
  local plugin = plugutils.safe_plugin_run(params.plugin_name, data)
  plugutils.respond_as_json(plugin)
end)

r:post('/_private/api/plugins/test/:plugin_name', function(params)
  local data
  if params.data then
    data = safe_json_decode(params.data)
  end
  local plugin = plugutils.plugin_test(params.plugin_name, data)
  plugutils.respond_as_json(plugin)
end)

r:get('/_private/api/plugins/stats/all', function(params)
  local list = plugutils.get_active()
  local resp = {}
  if not list then plugutils.respond_as_json({}) end
  for _, p in ipairs(list) do
    local stats = plugutils.plugin_stats(p)
    if not stats then
      resp[p] = {}
    else
      resp[p] = {errors = stats.errors, executions = stats.executions}
    end
  end
  plugutils.respond_as_json(resp)
end)

r:get('/_private/api/plugins/stats/:plugin_name', function(params)
  local plugin = plugutils.plugin_stats(params.plugin_name)
  plugutils.respond_as_json(plugin)
end)

r:get('/_private/api/plugins/details/all', function(params)
  local list = plugutils.get_active()
  local resp = {}
  if not list then plugutils.respond_as_json({}) end
  for _, p in ipairs(list) do
    local details = plugutils.plugin_details(p)
    if not details or details.err then
      resp[p] = {}
    else
      resp[p] = details
    end
  end
  plugutils.respond_as_json(resp)
end)

r:get('/_private/api/plugins/details/:plugin_name', function(params)
  local plugin = plugutils.plugin_details(params.plugin_name)
  plugutils.respond_as_json(plugin)
end)

r:get('/_private/api/plugins/list', function(params)
  local active_plugins = plugutils.get_active()
  plugutils.respond_as_json(active_plugins)
end)

r:get('/_private/api/lubot/botname', function(params)
  local botname = robot.brain:get('botname')
  plugutils.respond_as_json({botname = botname})
end)

local method = string.lower(ngx.req.get_method())
local path = ngx.var.uri
local query_params = {}
ngx.req.read_body()

if method == "post" or method == "put" then
  local q, err = ngx.req.get_body_data()
  if not q then
    log.warn("POST/PUT with no body data") 
  else
    query_params.data = q
  end
else
  query_params = ngx.var.args
end
r:execute(method, path, query_params)
