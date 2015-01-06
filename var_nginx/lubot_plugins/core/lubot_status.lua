local id = "status"
local version = "0.0.1"
local regex = [[status]]

local p = require 'utils.plugins'
local slack = require 'utils.slack'

local function run(data)

  local slack_running   = ngx.shared.slack_running
  local slack_users     = ngx.shared.slack_users
  local slack_groups    = ngx.shared.slack_groups
  local slack_channels  = ngx.shared.slack_channels
  local slack_ims       = ngx.shared.slack_ims
  local slack_bots      = ngx.shared.slack_bots
  local lubot_config    = ngx.shared.lubot_config

  local worker_pid = slack_running:get("locked")
  local users = #slack_users:get_keys()
  local groups = #slack_groups:get_keys()
  local channels = #slack_channels:get_keys()
  local ims = #slack_ims:get_keys()
  local bots = #slack_bots:get_keys()
  local config_file = lubot_config:get("config_file")


  fields = {
    {
      title = "Current worker pid",
      value = worker_pid,
      short = true
    },
    {
      title   = "Config file",
      value   = "`"..config_file.."`",
      short   = true,
      mrkdwn  = true
    },
    {
      title = "User count",
      value = users,
      short = true
    },
    {
      title = "My Private Groups",
      value = groups,
      short = true
    },
    {
      title = "Public Channels",
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
  local t = {
    text = "Current Status",
    fields = fields,
    channel = data.channel,
    username = p.get_botname()
  }
  local response = slack.to_rich_message(t)
  if not response then
    return nil
  else
    return response
  end
end

local function test(data)
  local res = run(data)
  if not res then return p.fail_test("plugin returned no data") end
  if type(res) ~= 'table' then return p.fail_test("not a table") end
  if not res.attachments and not res.attachments[1].fallback then return p.fail_test("rich message found but no fallback provided") end
  if res.channel ~= data.channel then return p.fail_test("channel mismatch") end
  return p.pass_test({results = res.attachments[1].fallback})
end

local plugin = {
  run = run,
  id = id,
  version = version,
  regex = regex,
  test = test
}

return plugin
