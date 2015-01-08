local m = {}

function m.logerr(...)
  ngx.log(ngx.ERR,...)
end

function m.logwarn(...)
  ngx.log(ngx.WARN,...)
end

function m.loginfo(...)
  ngx.log(ngx.INFO,...)
end

function m.logdebug(...)
  ngx.log(ngx.DEBUG,...)
end

function m.lognotice(...)
  ngx.log(ngx.NOTICE,...)
end

function m.logalert(...)
  ngx.log(ngx.ALERT,...)
end

function m.inspect(...)
  local inspect = require 'inspect'
  m.lognotice("Inspecting: ",inspect(...))
end

return m
