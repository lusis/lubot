local ngu = require 'utils.nginx'
local pu = require 'utils.plugins'
local m = {}

local function fields_to_fallback(fields)
  local t = {}
  for k, v in pairs(fields) do
    local txt = string.lower(v.title:gsub("%s+","_"))
    table.insert(t,txt..": "..v.value) 
  end
  return table.concat(t, " | ")
end

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

function m.say(text)
  return {text = text}
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

return m
