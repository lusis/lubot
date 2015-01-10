local b = {}
local _B = {}

b._VERSION = "0.0.1"

function b.new(...)
  local self = {}
  local args = ... or {}
  

  setmetatable(self, {__index = _M})
  return self
end

