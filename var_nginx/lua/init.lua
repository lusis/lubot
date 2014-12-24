-- These variables are all local to this file
local slack_token = os.getenv("SLACK_API_TOKEN")
local slack_webhook_url = os.getenv("SLACK_WEBHOOK_URL")
local shared_dict = ngx.shared.ng_shared_dict
shared_dict:set("startup_time", startup_time)
shared_dict:set("slack_token", slack_token)
shared_dict:set("slack_webhook_url", slack_webhook_url)
shared_dict:set("bot_name", "lubot")

function safe_json_decode(str)
  local log     = ngx.log
  local ERR     = ngx.ERR
  local INFO    = ngx.INFO
  local WARN    = ngx.WARN
  local DEBUG   = ngx.DEBUG
  local cjson = require 'cjson'
  local ok, data = pcall(cjson.decode, str)
  if not ok then
    log(ERR, "unable to decode json: ", err)
    return nil
  else
    return data
  end
end

function safe_json_encode(t)
  local log     = ngx.log
  local ERR     = ngx.ERR
  local INFO    = ngx.INFO
  local WARN    = ngx.WARN
  local DEBUG   = ngx.DEBUG
  local cjson = require 'cjson'
  local ok, data = pcall(cjson.encode, t)
  if not ok then
    log(ERR, "unable to decode json: ", data)
    return nil
  else
    return data
  end
end

function slackbot(premature)
  if premature then return nil end
  -- a few shortcuts
  local log     = ngx.log
  local ERR     = ngx.ERR
  local INFO    = ngx.INFO
  local WARN    = ngx.WARN
  local DEBUG   = ngx.DEBUG
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
    
    log(INFO, "Filling shared dict with initial details")
    for k, v in pairs(data.users) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_users:safe_set(v.id, str)
      if not o then
        log(ERR, "Unable to add user to shared_dict: ", e)
        errors.insert(v)
      end
    end
    for k, v in pairs(data.groups) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_groups:safe_set(v.id, str)
      if not o then
        log(ERR, "Unable to add group to shared_dict: ", e)
        errors.insert(v)
      end
    end
    for k, v in pairs(data.channels) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_channels:safe_set(v.id, str)
      if not o then
        log(ERR, "Unable to add channel to shared_dict: ", e)
        errors.insert(v)
      end
    end
    for k, v in pairs(data.bots) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_bots:safe_set(v.id, str)
      if not o then
        log(ERR, "Unable to add bots to shared_dict: ", e)
        errors.insert(v)
      end
    end
    for k, v in pairs(data.ims) do
      local str = safe_json_encode(v)
      if not str then break end
      local o, e = slack_ims:safe_set(v.id, str)
      if not o then
        log(ERR, "Unable to add ims to shared_dict: ", e)
        errors.insert(v)
      end
    end
    log(INFO, "Filled shared dict")
    if #errors > 0 then
      return false, errors
    else
      return true, nil
    end
  end

  local function wait(url)
    local slack_webhook_url = shared_dict:get('slack_webhook_url')
    if not slack_webhook_url then log(INFO, "No webhook url. Some plugins may not work") end
    local slack_token = shared_dict:get('slack_token')
    local botname = shared_dict:get('bot_name')
    if not slack_token then return false end
    local u = url or "https://slack.com/api/rtm.start?token="..slack_token
    -- log(INFO, "request url: ", u)
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
      log(ERR,'failed to connect to slack: '..err)
      return false
    end
    local data
    local body = res.body
    if not body then
      log(ERR, "Missing body", res.status)
      return false
    else
      data = safe_json_decode(body)
      if not data then return false end
    end
    -- Schedule a fill of shared dicts with the slack data from the initial auth
    -- local pok, perr = ngx.timer.at(0, fill_slack_dicts, data)
    local pok, perr = fill_slack_dicts(data)
    if not pok then
      log(ERR, "Failed to schedule filling of shared dicts with slack data: ", inspect(perr))
    end

    local rewrite_url_t = hc:urlparse(data.url)
    -- proxy_pass doesn't understand ws[s] urls so we fake it
    local rewrite_url = "https://"..rewrite_url_t.host..rewrite_url_t.path
    local proxy_url = 'ws://127.0.0.1:3131/wssproxy?url='..rewrite_url
    --log(INFO, "Proxy URL: ", proxy_url)
    local ws        = require 'resty.websocket.client'
    local wsc, wscerr = ws:new()
    local ok, connerr = wsc:connect(proxy_url)
    if not ok then
      log(ERR, "[failed to connect] ", connerr)
      return false
    end

    local function parse_command(cmd, msg_data, hook_url)
      --log(INFO, "got command: ", cmd, " from ", msg_data.user, " via ", msg_data.channel)
      -- switch to the cosocket library here since we want better perf
      local data = safe_json_encode(msg_data)
      if not data then return nil end
      local http = require 'resty.http'
      local httpc = http.new()
      httpc:connect("127.0.0.1", 3131)
      local res, err = httpc:request{
        method = "POST",
        path = "/lubot_plugin?plugin="..cmd,
        body = data
      }
      if err or res.status == 405 then
        log(ERR, "error running plugin: ", res.status)
        return nil
      elseif res.status == 204 then
        log(INFO, "Message sent via webhook")
        return nil
      else
        local body = res:read_body()
        httpc:set_keepalive()
        return body
      end
    end

    local users     = ngx.shared.slack_users
    local groups    = ngx.shared.slack_groups
    local channels  = ngx.shared.slack_channels
    local ims       = ngx.shared.slack_ims
    local bots       = ngx.shared.slack_bots
    local function get_source(c)
      local m, err = ngx.re.match(c, "^([A-Z]).*", "jo")
      if not m then log(ERR, "Error attempting match: ", err); return c end
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
        log(ERR, "[failed to recieve the frame] ", err)
        break
      end
      if not data then
        log(INFO, "[sending wss ping] ", typ)
        local bytes, err = wsc:send_ping()
        if not bytes then
          log(ERR, "[failed to send wss ping] ", err)
          break
        end
      elseif typ == "close" then break
      elseif typ == "ping" then
        log(INFO, "[wss ping] ", typ, " ("..data..")")
        local bytes, err = wsc:send_pong()
        if not bytes then
          log(ERR, "[failed to send wss pong] ", err)
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
            --log(INFO, inspect(res))
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
            log(INFO, "[",channel,"] ", user," ", res.text)
            local m, err = ngx.re.match(res.text, "^"..botname.." (\\w+).*", "jo")
            if not m then
              log(ERR, "Ignoring message not directed at me: ", err)
            else
            --local _, _, command = string.find(res.text, "^"..botname.."%s(%a+)")
              local command = m[1]
              if not command then
                log(INFO, "No command found")
              else
                if command == "die" then
                  if not u.is_admin then
                    log(INFO, "Ignoring non-admin user")
                  else
                    local m = {
                      ["type"] = "message",
                      text = "I am slain!",
                      channel = res.channel,
                      id = ngx.worker.pid()..ngx.time()
                    }
                    local bytes, err = wsc:send_text(safe_json_encode(m))
                    if err then
                      log(ERR, "Got an error sending die response: ", err)
                    end
                    break
                  end
                end
                response = parse_command(command, res)
                if not response then 
                  log(ERR, "empty response")
                else
                  local bytes, err = wsc:send_text(response)
                  if err then log(ERR, "Got an error responding: ", err) end
                end
              end
            end
          elseif res['type'] == 'hello' then
            log(INFO, "Connected!")
          elseif res['type'] == 'group_joined' then
            -- handle getting add to a new group
            local groups = ngx.shared.slack_groups
            local data = safe_json_encode(res.channel)
            local o, e = groups:safe_set(res.channel.id, data)
            if e then
              log(ERR, "Unable to add new group to shared_dict: ", e)
            end
          elseif res['type'] == 'user_typing' then
            -- skip it
          elseif res['type'] == 'presence_change' then
            -- skip it
          elseif res['reply_to'] then
            -- skip it
          else
            log(INFO, "[unknown type] ", data)
          end
        else
          log(ERR, "Error decoding json: ", inspect(data))
        end
      end
    end
    log(INFO, "WSS Loop broke out")
    return false
  end

  -- lua-resty-lock locks will always expire
  -- not suited for long-running locks
  -- instead we will gate the concurrent access to this function
  -- with a resty-lock and then use our own tracking
  -- internally
  --log(INFO, "My pid is: ", ngx.worker.pid())
  local working_worker_pid = slack_running:get("locked")
  --log(INFO, "Current worker pid is: ", working_worker_pid)
  local asking_worker_pid = ngx.worker.pid()
  if asking_worker_pid ~= working_worker_pid then
    --log(INFO, "Work already being done. Exiting")
    return false
  else
    log(INFO, "I am the current holder. Continuing")
    -- keys
    local slack_token = shared_dict:get('slack_token')
    -- third party
    inspect = require 'inspect'
    local wok, res = pcall(wait)
    local werr = wok or res
    if not wok or res == false then
      log(ERR, "Res loop exited: ", werr)
    else
      log(ERR, "You...shouldn't get here but I'm playing it safe")
    end
    return res
  end
end
