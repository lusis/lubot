local m = {}
local n = require 'utils.nginx'
local inspect = require 'inspect'

m.err = n.logerr
m.warn = n.logwarn
m.info = n.loginfo
m.debug = n.logdebug
m.notice = n.lognotice
m.alert = n.logalert

function m.inspect(t, ...)
  local args = {...}
  if #args > 0 then
    m.alert(table.concat(args, " "), inspect(t))
  else
    m.alert("inspecting :", inspect(t))
  end
end

return m
