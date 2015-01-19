local _brain = {}
local _B = {}
_brain._VERSION = "0.0.1"
_brain.name = "memory"
_brain.persistent = false
local inspect = require 'inspect'

function _brain.new(...)
  local self = {}
  setmetatable(self, {__index = _B})
  self._brainpan = {}
  return self
end

function _B:save()
  -- noop
  return true
end

function _B:keys()
  local t = {}
  for k, v in pairs(self._brainpan) do
    table.insert(t, k)
  end
  return t
end

function _B:export()
  -- noop
end

function _B:populate(t)
  self._brainpan = t
  return self._brainpan
end

function _B:get(k)
  return self._brainpan[k]
end

function _B:set(k, v)
  self._brainpan[k] = v
  return 1
end

function _B:safe_set(k, v)
  if self._brainpan[k] then
    return nil
  else
    self._brainpan[k] = v
    return 1
  end
end

function _B:delete(k)
  self._brainpan[k] = nil
end

function _B:flush()
  self._brainpan = {}
end
return _brain
