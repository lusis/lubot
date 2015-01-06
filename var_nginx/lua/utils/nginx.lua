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

return m
