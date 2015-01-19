local _VERSION = "0.0.1"
local template = require 'resty.template'
template.caching(false)

local shared_dict = ngx.shared.ng_shared_dict
local botname, err = shared_dict:get("bot_name")

local function landing_page()
  local content = template.compile("<h1>"..botname.." - the openresty chatbot</h1>")
  template.render("index.html", {
    ngx = ngx,
    botname = botname,
    content = content,
    menubar = menubar
  })
end

local function get_page(regex)
  local pagename = regex['path'] or '404'
  local plu = require 'utils.plugins'
  local active_plugins = plu.dicts.active:get_keys()
  local plugins = {}
  for _, k in pairs(active_plugins) do
    plugins[k] = {
      name = k,
      errors = plu.dicts.errors:get(k) or 0,
      config = plu.dicts.config:get(k) or "none",
      executions = plu.dicts.executions:get(k) or 0
    }
  end
  local subcontent = template.compile(pagename..".html"){active_plugins = plugins}
  if subcontent == pagename..".html" then
    subcontent = template.compile('404.html')
  end
  template.render("index.html", {
    menubar = menubar,
    ngx = ngx,
    botname = botname,
    content = subcontent
  })
end

local m, err = ngx.re.match(ngx.var.uri, [=[^/(?<path>\w+)(?<remainder>/.*$)?]=])
if not m then
  return landing_page()
else
  return get_page(m)
end
