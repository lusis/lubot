local _VERSION = "0.0.1"
-- These variables are all local to this file
local lubot_plugin_config = os.getenv("LUBOT_PLUGIN_CONFIG") or "/var/nginx/lubot_plugins/plugins.json"
local botname = os.getenv("LUBOT_BOTNAME") or "lubot"
local slack_token = os.getenv("SLACK_API_TOKEN") or nil
local slack_webhook_url = os.getenv("SLACK_WEBHOOK_URL")
-- default brain is a shared dictionary
local lubot_brain = os.getenv("LUBOT_BRAIN") or "ngx_shared"
local lubot_brain_opts = os.getenv("LUBOT_BRAIN_OPTS")

local shared_dict = ngx.shared.ng_shared_dict
local lubot_config = ngx.shared.lubot_config
lubot_config:set("config_file", lubot_plugin_config)
shared_dict:set("startup_time", startup_time)
shared_dict:set("slack_token", slack_token)
shared_dict:set("slack_webhook_url", slack_webhook_url)
shared_dict:set("bot_name", botname)

local ngu = require 'utils.nginx'
local pu = require 'utils.plugins'
local slack = require 'utils.slack'
local log = require 'utils.log'

local inspect = require 'inspect'

menubar = {
  ["Slack"] = "/slack",
  ["Plugins"] = "/plugins",
  ["Logs"] = "/logs",
  ["Docs"] = "/docs/index"
}

robot = {}

if lubot_brain == 'memory' then
  print("Memory brain is invalid for nginx. Switching to ngx_shared")
  lubot_brain = 'ngx_shared'
end
local brain_ok, brain  = pcall(require, 'utils.brain')
if not brain_ok then
  print("Failed to load brain. This won't work....")
else
  robot.brain = brain.new(lubot_brain, lubot_brain_opts)
  robot.brain:set('botname', botname)
  robot.brain:set('config_file', lubot_plugin_config)
end

function safe_json_decode(str)
  if not str then
    log.err("no string passed in for decoding")
    return nil
  end
  local caller = debug.getinfo(2).name
  local cjson = require 'cjson'
  local ok, data = pcall(cjson.decode, str)
  if not ok then
    log.err("unable to decode json from "..caller..": ", data)
    return nil
  else
    return data
  end
end

function safe_json_encode(t)
  local cjson = require 'cjson'
  local ok, data = pcall(cjson.encode, t)
  if not ok then
    log.err("unable to encode json: ", data)
    return nil
  else
    return data
  end
end

function slackbot(premature)
  if premature then return nil end
  -- shared dicts
  local slack_running = ngx.shared.slack_running
  local shared_dict   = ngx.shared.ng_shared_dict
  local locks         = ngx.shared.shared_locks

  local function fill_slack_dicts(data)
    if not data then return false, "Missing data" end
    local errors = {}
    local slack_users     = ngx.shared.slack_users
    local slack_groups    = ngx.shared.slack_groups
    local slack_channels  = ngx.shared.slack_channels
    local slack_ims       = ngx.shared.slack_ims
    local slack_bots      = ngx.shared.slack_bots
    
    log.alert("Filling shared dict with initial details")

    for k, v in pairs(data.users) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_users:safe_set(v.id, str)
      if not o then
        log.err("Unable to add user to shared_dict: ", e)
        errors.insert(v)
      end
      local bo  = robot.brain:safe_set(v.id, v)
      if not bo then
        log.err("failed to add data to brain")
      end
      robot.brain:save()
    end
    for k, v in pairs(data.groups) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_groups:safe_set(v.id, str)
      if not o then
        log.err("Unable to add group to shared_dict: ", e)
        errors.insert(v)
      end
      local bo  = robot.brain:safe_set(v.id, v)
      if not bo then
        log.err("failed to add data to brain")
      end
      robot.brain:save()
    end
    for k, v in pairs(data.channels) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_channels:safe_set(v.id, str)
      if not o then
        log.err("Unable to add channel to shared_dict: ", e)
        errors.insert(v)
      end
      local bo  = robot.brain:safe_set(v.id, v)
      if not bo then
        log.err("failed to add data to brain")
      end
      robot.brain:save()
    end
    for k, v in pairs(data.bots) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_bots:safe_set(v.id, str)
      if not o then
        log.err("Unable to add bots to shared_dict: ", e)
        errors.insert(v)
      end
      local bo  = robot.brain:safe_set(v.id, v)
      if not bo then
        log.err("failed to add data to brain")
      end
      robot.brain:save()
    end
    for k, v in pairs(data.ims) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_ims:safe_set(v.id, str)
      if not o then
        log.err("Unable to add ims to shared_dict: ", e)
        errors.insert(v)
      end
      local bo  = robot.brain:safe_set(v.id, v)
      if not bo then
        log.err("failed to add data to brain")
      end
      robot.brain:save()
    end
    log.alert("Filled shared dict")
    if #errors > 0 then
      return false, errors
    else
      return true, nil
    end
  end

  local function wait(url)
    if not robot.brain then
      return false
    end
    local plugin_config = pu.load_config()
    local slack_webhook_url = shared_dict:get('slack_webhook_url')
    if not slack_webhook_url then log.alert("No webhook url. Some plugins may not work") end
    local slack_token = shared_dict:get('slack_token')
    local botname = shared_dict:get('bot_name')
    if not slack_token then return false end
    local u = url or "https://slack.com/api/rtm.start?token="..slack_token
    -- we use httpclient here because we don't have
    -- ngx.location.capture available in this context
    -- and resty-http has stupid SSL issues
    -- It's okay to block this request anyway...sort of
    local hc = require 'httpclient'.new()
    local reqheaders = {
          ["User-Agent"] = botname.." 0.0.1",
          ["Accept"] = "application/json",
          ["Content-Type"] = "application/json"
    }
    local res = hc:get(u,{ headers = reqheaders})
    if res.err then
      log.err('failed to connect to slack: '..err)
      return false
    end
    local data
    local body = res.body
    if not body then
      log.err("Missing body", res.status)
      return false
    else
      data = safe_json_decode(body)
      if not data then return false end
    end
    -- Schedule a fill of shared dicts with the slack data from the initial auth
    -- local pok, perr = ngx.timer.at(0, fill_slack_dicts, data)
    local pok, perr = fill_slack_dicts(data)
    if not pok then
      log.err("Failed to schedule filling of shared dicts with slack data: ", inspect(perr))
    end
    local rewrite_url_t = hc:urlparse(data.url)
    -- proxy_pass doesn't understand ws[s] urls so we fake it
    local rewrite_url = "https://"..rewrite_url_t.host..rewrite_url_t.path
    local proxy_url = 'ws://127.0.0.1:3131/wssproxy?url='..rewrite_url
    local ws        = require 'resty.websocket.client'
    local wsc, wscerr = ws:new()
    local ok, connerr = wsc:connect(proxy_url)
    if not ok then
      log.err("[failed to connect] ", connerr)
      return false
    end

    local function parse_command(cmd, msg_data)
      -- switch to the cosocket library here since we want better perf
      local data = safe_json_encode(msg_data)
      if not data then return nil end
      local channel = msg_data.channel
      local http = require 'resty.http'
      local httpc = http.new()
      httpc:connect("unix:/var/nginx/tmp/ngx.private.sock")
      httpc:set_timeout(5000)
      local res, err = httpc:request{
        method = "POST",
        path = "/_private/api/plugins/run/"..cmd,
        headers = {["Host"] = "localhost", ["Content-Type"] = "application/json"},
        body = data
      }
      if not res then
        log.err("Got no response from request. That's bad")
        httpc:set_keepalive()
        return nil
      end
      httpc:set_keepalive()
      if err or res.status == 405 then
        log.err("error running plugin: ", res.status)
        httpc:set_keepalive()
        return nil
      else
        local body = res:read_body()
        local decoded_body = safe_json_decode(body)
        if not decoded_body then
          log.alert([[plugin response does not appear to be json]])
          httpc:set_keepalive()
          return nil
        end
        if decoded_body.attachments then
          httpc:set_timeout(10000)
          local res, err = httpc:request{
            method = "POST",
            path = "/_private/slackpost",
            headers = {["Host"] = "localhost", ["Content-Type"] = "application/json"},
            body = body
          }
          httpc:set_keepalive()
          if not res or res.status ~= 200 then
            -- chat message failed
            httpc:set_keepalive()
            log.err("Unable to rich message to slack api: "..err)
            return nil
          else
            return true
          end
        else
          httpc:set_keepalive()
          local text = decoded_body.text
          local msg = slack.to_rts_message(text, channel)
          return msg
        end
      end
    end

    local users     = ngx.shared.slack_users
    local groups    = ngx.shared.slack_groups
    local channels  = ngx.shared.slack_channels
    local ims       = ngx.shared.slack_ims
    local bots       = ngx.shared.slack_bots
    local function get_source(c)
      local m, err = ngx.re.match(c, "^([A-Z]).*", "jo")
      if not m then log.err("Error attempting match: ", err); return c end
      --log(INFO, "Matched ", c, " as type ", m[1])
      if m[1] == 'D' then return safe_json_decode(ims:get(c)) end
      if m[1] == 'C' then return safe_json_decode(channels:get(c)) end
      if m[1] == 'G' then return safe_json_decode(groups:get(c)) end
      if m[1] == 'B' then return safe_json_decode(bots:get(c)) end
      if m[1] == 'U' then return safe_json_decode(users:get(c)) end
    end
    while true do
      local data, typ, err = wsc:recv_frame()
      if wsc.fatal then
        log.err("[failed to recieve the frame] ", err)
        break
      end
      if not data then
        log.alert("[sending wss ping] ", typ)
        local bytes, err = wsc:send_ping()
        if not bytes then
          log.err("[failed to send wss ping] ", err)
          break
        end
      elseif typ == "close" then break
      elseif typ == "ping" then
        log.alert("[wss ping] ", typ, " ("..data..")")
        local bytes, err = wsc:send_pong()
        if not bytes then
          log.err("[failed to send wss pong] ", err)
          break
        end
      elseif typ == "text" then
        local res = safe_json_decode(data)
        if res then
          if res['type'] == 'message' and res['subtype'] == 'message_changed' then
            -- ignore it
          elseif res['type'] == 'message' and res['subtype'] == 'bot_message' then
            -- ignore it
          elseif res.reply_to then
            -- ignore it
          elseif res['type'] == 'message' then
            local channel
            local c = get_source(res.channel) or nil
            if not c then
              channel = res.channel
            else
              if c.is_im then channel = 'private' else channel = c.name end
            end
            local user
            local u = get_source(res.user) or nil
            if not u then
              user = res.user
            else
              user = u.name
            end
            local m, err = ngx.re.match(res.text, "^"..botname.." (.*)$", "jo")
            if not m then
              -- we don't care if it's not directed at us
            else
              local command = m[1]
              if not command then
                log.warn("No command found")
              else
                if command == "die" then
                  if not u.is_admin then
                    log.alert("Ignoring non-admin user")
                  else
                    local m = {
                      ["type"] = "message",
                      text = "I am slain!",
                      channel = res.channel,
                      id = ngx.worker.pid()..ngx.time()
                    }
                    local bytes, err = wsc:send_text(safe_json_encode(m))
                    if err then
                      log.err("Got an error sending die response: ", err)
                    end
                    break
                  end
                end
                local candidates = pu.find_plugin_for(command)
                if #candidates == 1 then
                  local response = parse_command(candidates[1].id, res)
                  if not response then 
                    log.warn("empty response")
                  elseif response == true then
                    -- post message via webhook successfully
                  else
                    local reply = safe_json_encode(response)
                    if not reply then
                      log.err("Got an error encoding json for reply")
                    else
                      local bytes, err = wsc:send_text(reply)
                      if err then log.err("Got an error responding: ", err) end
                    end
                  end
                elseif #candidates > 1 then
                  log.alert("Multiple candidates for command. This should never happen")
                else
                  -- do nothing
                end
              end
            end
          elseif res['type'] == 'hello' then
            log.alert("Connected!")
          elseif res['type'] == 'group_joined' then
            -- handle getting add to a new group
            local groups = ngx.shared.slack_groups
            local data = safe_json_encode(res.channel)
            local o, e = groups:safe_set(res.channel.id, data)
            if e then
              log.warn("Unable to add new group to shared_dict: ", e)
            end
          elseif res['type'] == 'user_typing' then
            -- skip it
          elseif res['type'] == 'presence_change' then
            -- skip it
          elseif res['reply_to'] then
            -- skip it
          elseif res['type'] == 'file_change' then
            -- skip it
          elseif res['type'] == 'file_shared' then
            -- skip it
          else
            log.notice("[unknown type] ", data)
          end
        else
          log.err("Error decoding json: ", inspect(data))
        end
      end
    end
    log.notice("WSS Loop broke out")
    return false
  end

  -- lua-resty-lock locks will always expire
  -- not suited for long-running locks
  -- instead we will gate the concurrent access to this function
  -- with a resty-lock and then use our own tracking
  -- internally
  local working_worker_pid = slack_running:get("locked")
  local asking_worker_pid = ngx.worker.pid()
  if asking_worker_pid ~= working_worker_pid then
    return false
  else
    log.alert("I am the current holder. Continuing")
    -- keys
    local slack_token = shared_dict:get('slack_token')
    -- third party
    local wok, res = pcall(wait)
    local werr = wok or res
    if not wok or res == false then
      log.err("Res loop exited: ", werr)
    else
      log.alert("You...shouldn't get here but I'm playing it safe")
    end
    return res
  end
end
