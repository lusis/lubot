local _brain = {}
local _B = {}
_brain._VERSION = "0.0.1"
_brain.name = "ngx_shared"
_brain.persistent = false

local log = require 'utils.log'

function _brain.new(...)
  local self = {}
  local args = ... or {}
  setmetatable(self, {__index = _B})
  if not args.shared_dict then
    print("No shared dictionary specified. Using default.")
    self._shared_dict = ngx.shared.lubot_brain
  else
    self._shared_dict = ngx.shared[args.shared_dict]
  end
  local success, err, forcible = self._shared_dict:set('activated_brain', true)
  if not success then
    print("Could not set test data in brain: "..err)
    return nil
  else
    print("Successfully wrote to the brain")
  end
  return self
end

local function json_decode(str)
  local cjson = require 'cjson'
  local json_ok, json = pcall(cjson.decode, str)
  if not json_ok then
    return nil
  else
    return json
  end
end

local function json_encode(t)
  local cjson = require 'cjson'
  local json_ok, json = pcall(cjson.encode, t)
  if not json_ok then
    return nil
  else
    return json
  end
end

function _B:save()
  -- noop for now
end

function _B:keys()
  local keys = self._shared_dict:get_keys(0)
  return keys
end

function _B:export()
  local t = {}
end

function _B:populate()
end

function _B:get(k)
  local value = self._shared_dict:get(k)
  if not value then
    return nil
  else
    local dec = json_decode(value)
    if not dec then
      return nil
    else
      return dec
    end
  end
end

function _B:set(k, v)
  local enc = json_encode(v)
  if enc then
    local ok, err, force = self._shared_dict:set(k, enc)
    if not ok then
      log.err("Unable to set key in shared_dict")
      return nil
    else
      return 1
    end
  else
    log.err("Unable to encode value for shared_dict")
    return nil
  end
end

function _B:safe_set(k, v)
  local encoded_value
  local e = json_encode(v)
  if not e then
    log.err("Unable to encode data to json for key: ", k)
    return nil
  else
    encoded_value = e
  end
  local success, err, forcible = self._shared_dict:safe_add(k, encoded_value)
  if not success then
    log.err("Unable to insert value for key "..k.." into dict")
    return nil
  else
    return encoded_value
  end
end

function _B:delete(k)
  self._shared_dict:delete(k)
end

function _B:flush()
  self._shared_dict:flush_all()
  self._shared_dict:flush_expired()
end

return _brain
