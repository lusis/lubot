local inspect = require 'inspect'

-- a few shortcuts
local log     = ngx.log
local ERR     = ngx.ERR
local INFO    = ngx.INFO
local WARN    = ngx.WARN
local DEBUG   = ngx.DEBUG

local shared_dict = ngx.shared.ng_shared_dict
local slack_webhook_url = shared_dict:get("slack_webhook_url")
-- this code has a lot of error checking and safety baked in
-- we safe decode/encode all json (see init.lua global functions)
-- we pcall the plugin execution to ensure safe running
-- we always exit 405 in the event of a problem
local function plugin_error(msg)
  log(ERR, "Plugin errored with message: ", msg)
  ngx.exit(ngx.HTTP_NOT_ALLOWED)
end

local function send_incoming_webhook(msg)
  local hc = require 'httpclient'.new('httpclient.ngx_driver')
  if not slack_webhook_url then
    log(ERR, "Cannot send via webhook. Missing url")
    return nil
  else
    log(INFO, "Sending response via webhook")
    local res = hc:post(slack_webhook_url, msg, {headers = {accept = "application/json"}, content_type = "application/json"})
    if res.err then
      log(ERR, "Error sending webhook response: ", res.err)
      return nil
    else
      log(INFO, "Response sent via webhook: ", res.status)
      return true
    end
  end
end

local function send_rts_message(msg)
    log(INFO, "Sending RTS response")
    ngx.header.content_type = "application/json"
    ngx.say(msg)
    ngx.exit(ngx.HTTP_OK)
end

local args = ngx.req.get_uri_args()
if not args.plugin then
  plugin_error("Plugin name not passed")
else
  local plugin_ok, plugin = pcall(require, "lubot_"..args.plugin)
  if not plugin_ok then
    plugin_error("Plugin "..args.plugin.." not found")
  end
  if not ngx.var.request_body then
    plugin_error("Missing data for plugin")
  end
  local decoded_data = safe_json_decode(ngx.var.request_body)
  if not decoded_data then
    plugin_error("Unable to decode request body")
  end
  log(INFO, "Running ",plugin.id," version ", plugin.version)
  local run_ok, res, err = pcall(plugin.run,decoded_data)
  if not run_ok then
    plugin_error("Plugin did not run safely: "..res)
  elseif err then
    plugin_error("Plugin returned an error: "..err)
  else
    local encoded_data = safe_json_encode(res)
    if not encoded_data then
      plugin_error("Response did not encode properly")
    end
    if res.attachments then
      local wh = send_incoming_webhook(encoded_data)
      if not wh then
        log(INFO, "Unable to send via webhook. Attempting rts")
        res.channel = decoded_data.channel
        res['type'] = "message"
        res.text = res.attachments.fallback or res.text
        local recoded_data = safe_json_encode(res)
        if not recoded_data then
          plugin_error("Unable to re-encode response for rts")
        end
        return send_rts_message(recoded_data)
      else
        ngx.exit(204)
      end
    else
      return send_rts_message(encoded_data)
    end
  end
end
