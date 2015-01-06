local router = require 'router'
local inspect = require 'inspect'
local plugutils = require 'utils.plugins'
local r = router.new()

r:post('/_private/api/plugins/run/:plugin_name', function(params)
  local data = safe_json_decode(params.data)
  local plugin = plugutils.safe_plugin_run(params.plugin_name, data)
  plugutils.respond_as_json(plugin)
end)

r:post('/_private/api/plugins/test/:plugin_name', function(params)
  local data = safe_json_decode(params.data)
  local plugin = plugutils.plugin_test(params.plugin_name, data)
  plugutils.respond_as_json(plugin)
end)

r:get('/_private/api/plugins/stats/:plugin_name', function(params)
  local plugin = plugutils.plugin_stats(params.plugin_name)
  plugutils.respond_as_json(plugin)
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
  local botname = plugutils.get_botname()
  plugutils.respond_as_json({botname = botname})
end)

local method = string.lower(ngx.req.get_method())
local path = ngx.var.uri
local query_params = {}
ngx.req.read_body()

if method == "post" or method == "put" then
  local q, err = ngx.req.get_body_data()
  if not q then
    -- no params
  else
    query_params.data = q
  end
else
  query_params = ngx.var.args
end
r:execute(method, path, query_params)
