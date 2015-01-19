local ngu = require 'utils.nginx'
local pu = require 'utils.plugins'
local log = require 'utils.log'
local m = {}
m._VERSION = "0.0.1"

local function fields_to_fallback(fields)
  local t = {}
  for k, v in pairs(fields) do
    local txt = string.lower(v.title:gsub("%s+","_"))
    table.insert(t,txt..": "..v.value) 
  end
  return table.concat(t, " | ")
end

m.users_dict      = ngx.shared.slack_users
m.groups_dict     = ngx.shared.slack_groups
m.channels_dict   = ngx.shared.slack_channels
m.ims_dict        = ngx.shared.slack_ims
m.bots_dict       = ngx.shared.slack_bots

function m.make_slack_attachment(text, fields, fallback)
  local t = {}
  t.text = text
  t.fields = fields
  t.mrkdwn_in = {"pretext", "text", "title", "fields", "fallback"}
  if not fallback then
    t.fallback = fields_to_fallback(fields)
  else
    t.fallback = fallback
  end
  return t
end

function m.to_rts_message(text, channel)
  local t = {
    ["type"] = "message",
    channel = channel,
    id = pu.generate_id(),
    text = text
  }
  return t
end

function m.say(...)
  return {text = table.concat({...}," ")}
end

function m.to_rich_message(...)
  local required_fields = {"text", "fields", "channel", "username"}
  local args = ...
  for _,k in pairs(required_fields) do
    if not args[k] then return nil end
  end
  local fallback = args.fallback or nil
  local attachments = m.make_slack_attachment(args.text, args.fields, fallback)
  local t = {
    channel = args.channel,
    username = args.username,
    attachments = {attachments}
  }
  local shared_dict = ngx.shared.ng_shared_dict
  local slack_webhook_url = shared_dict:get('slack_webhook_url')
  if not slack_webhook_url then
    ngu.logwarn("No slack webhook url, converting message to rts fallback")
    return m.to_rts_message(attachments.fallback, args.channel)
  else
    return t
  end
end

function m.post_chat_message(...)
  local args = ...
  local hc = require 'httpclient'.new('httpclient.ngx_driver')
  local shared_dict = ngx.shared.ng_shared_dict
  local webhook_url = shared_dict:get('slack_webhook_url')
  if not webhook_url then return nil, "Slack webhook url missing" end
  local res = hc:post(webhook_url, args, {headers = {accept = "application/json"}, content_type = "application/json"})
  return res
end

function m.lookup_by_id(c)
  local users = m.users_dict
  local groups = m.groups_dict
  local channels = m.channels_dict
  local ims = m.ims_dict
  local bots = m.bots_dict
  
  local result
  local match, err = ngx.re.match(c, "^([A-Z]).*", "jo")
  if not match then
    log.err("Unable to match id to type")
    result = nil
  else
    if match[1] == 'D' then result = safe_json_decode(ims:get(c)) end
    if match[1] == 'C' then result = safe_json_decode(channels:get(c)) end
    if match[1] == 'G' then result = safe_json_decode(groups:get(c)) end
    if match[1] == 'B' then result = safe_json_decode(bots:get(c)) end
    if match[1] == 'U' then result = safe_json_decode(users:get(c)) end
  end
  return result
end

function m.id_to_user(u)

end

function m.id_to_channel(c)
end

function m.user_is_admin(u)
end

function m.user_is_restricted(u)
end

function m.user_id_ultra_restricted(u)
end
return m
