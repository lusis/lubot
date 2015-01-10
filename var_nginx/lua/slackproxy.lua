local _VERSION = "0.0.1"

local slack = require 'utils.slack'
local pu = require 'utils.plugins'
local ngu = require 'utils.nginx'

ngx.req.read_body()
local data = ngx.req.get_body_data()
if not data or data == ngx.null then
  ngu.logerr("Post to slack proxy with empty body")
  return nil
else
  local res, err = slack.post_chat_message(data)
  if res.status == 200 then
    return true
  else
    return nil
  end
end

