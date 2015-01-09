local m = {}
local n = require 'utils.nginx'

function m.err(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.ERR, ...)
  else
    ngx.log(ngx.ERR,"["..caller.."] ", ...)
  end
end

function m.warn(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.WARN, ...)
  else
    ngx.log(ngx.WARN,"["..caller.."] ", ...)
  end
end

function m.info(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.INFO, ...)
  else
    ngx.log(ngx.INFO,"["..caller.."] ", ...)
  end
end

function m.debug(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.DEBUG, ...)
  else
    ngx.log(ngx.DEBUG,"["..caller.."] ", ...)
  end
end

function m.notice(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.NOTICE, ...)
  else
    ngx.log(ngx.NOTICE,"["..caller.."] ", ...)
  end
end

function m.alert(...)
  local caller = debug.getinfo(2).name
  if not caller then
    ngx.log(ngx.ALERT,...)
  else
    ngx.log(ngx.ALERT,"["..caller.."] ",...)
  end
end

function m.inspect(t, ...)
  local inspect = require 'inspect'
  local caller = debug.getinfo(2).name
  local args = {...}
  if #args > 0 then
    if not caller then
      m.alert(table.concat(args, " "), inspect(t))
    else
      m.alert(caller..":", table.concat(args, " "), inspect(t))
    end
  else
    if not caller then
      m.alert("inspecting :", inspect(t))
    else
      m.alert("inspecting "..caller..":", inspect(t))
    end
  end
end

return m
