-- a few shortcuts
local log     = ngx.log
local ERR     = ngx.ERR
local INFO    = ngx.INFO
local WARN    = ngx.WARN
local DEBUG   = ngx.DEBUG

-- shared dicts
local shared_dict = ngx.shared.ng_shared_dict
local locks         = ngx.shared.shared_locks

local slack_token = shared_dict:get('slack_token')

local function start_rtm(premature)
  if premature then return nil end
  local slock = require 'resty.lock'
  local mylock = slock:new("shared_locks",{timeout = 60, exptime = 120})
  local locked, err = mylock:lock("slack_polling")
  if err then
    log(INFO, "Couldn't get lock. Sleeping then starting over")
    ngx.sleep(60)
  else
    --log(INFO, ngx.worker.pid(), " got the resty lock")
    local slack_running = ngx.shared.slack_running
    local ok, err = slack_running:add("locked", ngx.worker.pid())
    if err then
      --log(ERR, "Unable to set running status: ", err)
      if slack_running:get("locked") == ngx.worker.pid() then
        -- we couldn't get a lock to run but we're listed as the pid owner
        -- this likely means our thread crashed
        -- let's clear this lock and start fresh
        log(INFO, "previous lock holder thread likely crashed. starting over")
        slack_running:delete("locked")
      end
      local ok, err = mylock:unlock()
      if not ok then
        log(ERR, "Unable to clear lock: ", err)
      else
        log(INFO, "Locked held for ", locked)
      end
      ngx.sleep(60)
    else
      log(INFO, ngx.worker.pid(), " set the internal lock")
      -- we can clear the lock now as we've set our pid
      local ok, err = mylock:unlock()
      if not ok then
        log(ERR, "Unable to clear lock: ", err)
      else
        log(INFO, "Locked held for ", locked)
      end
      res = slackbot()
      if res == false then
        slack_running:delete("locked")
        log(ERR, "Slackbot function exited for some reason")
      end
    end
  end
  -- wait before starting the loop again
  -- previous we relied on lock waits but
  -- since we release after setting our other lock
  -- we have to emulate that
  start_rtm(nil)
end

-- main entry
if not slack_token then
  log(ERR,"Gotta set a slack token")
  return nil
else
  local ok, err = ngx.timer.at(1, start_rtm)
  if not ok then
    --log(INFO, "Failed to start initial timer")
  else
    log(INFO, "Initial timer started")
  end
end
