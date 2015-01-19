local shared_dict = ngx.shared.ng_shared_dict
local log_dict = ngx.shared.plugin_log

-- following helper function was cribbed from the fine folks at 3scale
-- https://github.com/3scale/nginx-oauth-templates/blob/master/oauth2/authorization-code-flow/no-token-generation/nginx.lua#L76-L90
function string:split(delimiter)
  local result = { }
  local from = 1
  local delim_from, delim_to = string.find( self, delimiter, from )
  
  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from )
  end
  
  table.insert( result, string.sub( self, from ) )
  
  return result
end

local function start_log_tailer()
  ngx.log(ngx.ALERT, "Client connected to sse")
  ngx.header.content_type = 'text/event-stream'
  ngx.say("event: keepalive\ndata: "..ngx.utctime().."\n")
  while true do
    local log_entries = log_dict:get_keys()
    for _, k in ipairs(log_entries) do
      local e = log_dict:get(k)
      local str_t = k:split(":")
      local msg = {
        id        = k,
        timestamp = str_t[2],
        sender    = str_t[1],
        message   = e
      }
      local json = safe_json_encode(msg)
      if not json then
        ngx.say("data: ["..k.."] "..e.."\n")
      else
        ngx.say("id: "..k.."\nevent: logevent\ndata: "..json.."\n")
      end
    end
    ngx.say("event: keepalive\ndata: "..ngx.utctime().."\n")
    ngx.flush(true)
    ngx.sleep(15)
  end
end
local ok, err = ngx.on_abort(function ()
    ngx.log(ngx.ALERT, "Client disconnected from sse stream")
    ngx.exit(499)
end)
if not ok then
    ngx.log(ngx.ERR, "Can't register on_abort function.")
    ngx.exit(500)
end
start_log_tailer()
