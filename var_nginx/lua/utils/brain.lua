local _brain = {}
local _B = {}
_brain._VERSION = "0.0.1"

local log = require 'utils.log'

function _brain.new(driver, driver_opts)
  local self = {}
  setmetatable(self, {__index = _B})
  local d
  if not driver then
    print('No driver specified. Using memory')
    d = 'memory_brain'
  else
    print('Using driver: '..driver)
    d = driver..'_brain'
  end
  local p_ok, p = pcall(require, d)
  if not p_ok then
    print("Got error requiring brain module: "..p)
    return nil
  else
    self.__driver = p
    self.driver_name = p.name
    if p.persistent == false then
      print("Warning! Using a non-persistent brain. Data will be lost at shutdown")
    end
  end
  self.driver = p.new(unpack{driver_opts})
  if not self.driver then
    print("Could not instantiate new brain")
    return nil
  end
  return self
end

function _B:save(...)
  return self.driver:save(unpack({...}))
end

function _B:keys(...)
  return self.driver:keys(unpack({...}))
end

function _B:export(...)
  return self.driver:export(unpack({...}))
end

function _B:populate(...)
  return self.driver:populate(unpack({...}))
end

function _B:get(...)
  return self.driver:get(unpack({...}))
end

function _B:set(...)
  return self.driver:set(unpack({...}))
end

function _B:safe_set(...)
  return self.driver:safe_set(unpack({...}))
end

function _B:delete(...)
  return self.driver:delete(unpack({...}))
end

function _B:flush(...)
  return self.driver:flush(unpack({...}))
end


return _brain
