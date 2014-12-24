local id = "lubot-status"
local version = "0.0.1"

local function run(data)
  local worker_id = ngx.worker.pid()
  local tstamp = ngx.time()

  local resp = {
    channel = data.channel,
    username = "testbot",
    attachments = {}
  }

  local slack_running = ngx.shared.slack_running
  local slack_users     = ngx.shared.slack_users
  local slack_groups    = ngx.shared.slack_groups
  local slack_channels  = ngx.shared.slack_channels
  local slack_ims       = ngx.shared.slack_ims
  local slack_bots      = ngx.shared.slack_bots

  local worker_pid = slack_running:get("locked")
  local users = #slack_users:get_keys()
  local groups = #slack_groups:get_keys()
  local channels = #slack_channels:get_keys()
  local ims = #slack_ims:get_keys()
  local bots = #slack_bots:get_keys()

  local attachment = {
    text = "Current status",
    fallback = "worker_pid: "..worker_pid.."|known_users: "..users.."|my_private_groups: "..groups.."|public_channels: "..channels.."|ims: "..ims.."|integrations: "..bots,
    fields = {
      {
        title = "Current worker pid",
        value = worker_pid,
        short = true
      },
      {
        title = "User count",
        value = users,
        short = true
      },
      {
        title = "Private Groups I'm in",
        value = groups,
        short = true
      },
      {
        title = "Public channels",
        value = channels,
        short = true
      },
      {
        title = "IMs",
        value = ims,
        short = true
      },
      {
        title = "Total integrations",
        value = bots,
        short = true
      }
    }
  }
  resp.attachments = {attachment}
  return resp
end

local plugin = {
  run = run,
  id = id,
  version = version
}

return plugin
