local ngu = require 'utils.nginx'

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
    ngx.sleep(60)
  else
    local slack_running = ngx.shared.slack_running
    local ok, err = slack_running:add("locked", ngx.worker.pid())
    if err then
      if slack_running:get("locked") == ngx.worker.pid() then
        -- we couldn't get a lock to run but we're listed as the pid owner
        -- this likely means our thread crashed
        -- let's clear this lock and start fresh
        ngu.logwarn("previous lock holder thread likely crashed. starting over")
        slack_running:delete("locked")
      end
      local ok, err = mylock:unlock()
      if not ok then
        ngu.logerr("Unable to clear lock: ", err)
      else
        ngu.logdebug("Locked held for ", locked)
      end
      ngx.sleep(60)
    else
      ngu.logdebug(ngx.worker.pid(), " set the internal lock")
      -- we can clear the lock now as we've set our pid
      local ok, err = mylock:unlock()
      if not ok then
        ngu.logerr("Unable to clear lock: ", err)
      else
        ngu.logdebug("Locked held for ", locked)
      end
      res = slackbot()
      if res == false then
        slack_running:delete("locked")
        ngu.logerr("Slackbot function exited for some reason")
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
  ngu.logerr("Gotta set a slack token")
  return nil
else
  local ok, err = ngx.timer.at(1, start_rtm)
  if not ok then
    -- skip
  else
    ngu.logdebug("Initial timer started")
  end
end
