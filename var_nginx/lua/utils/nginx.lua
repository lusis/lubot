local m = {}

function m.logerr(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.ERR, ...)
  else
    ngx.log(ngx.ERR,"["..caller.."] ", ...)
  end
end

function m.logwarn(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.WARN, ...)
  else
    ngx.log(ngx.WARN,"["..caller.."] ", ...)
  end
end

function m.loginfo(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.INFO, ...)
  else
    ngx.log(ngx.INFO,"["..caller.."] ", ...)
  end
end

function m.logdebug(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.DEBUG, ...)
  else
    ngx.log(ngx.DEBUG,"["..caller.."] ", ...)
  end
end

function m.lognotice(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.NOTICE, ...)
  else
    ngx.log(ngx.NOTICE,"["..caller.."] ", ...)
  end
end

function m.logalert(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.ALERT,...)
  else
    ngx.log(ngx.ALERT,"["..caller.."] ",...)
  end
end

function m.inspect(...)
  local caller = debug.getinfo(2).name
  local inspect = require 'inspect'
  if not caller then
    ngx.log(ngx.ALERT,"Inspecting: ",inspect(...))
  else
    ngx.log(ngx.ALERT, "Inspecting "..caller..":", inspect(...))
  end
end

return m
