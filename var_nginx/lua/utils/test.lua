local m = {}
local _M = {}

function m.new(...)
  local self = {}
  local args = ... or {}
  self.mock_data = args.mock_data or nil
  self.expects = args.expects or nil
  self.run_data = args.run_data or nil
  self.failures = {}
  self.tests = {}
  setmetatable(self, {__index = _M})
  return self
end

function _M:set_expects(str)
  self.expects = str
end

function _M:set_mock_data(t)
  self.mock_data = t
end

function _M:set_rundata(t)
  self.run_data = t
end

-- Verify the slack attachment response is correctly formatted
function _M:is_valid_rich_text(...)
  if not self.run_data then
    self:fail("Missing run data")
  else
    if not self.run_data.attachments then self:fail("Missing attachments") end
    if not self.run_data.attachments[1].fallback then self:fail("Missing fallback text") end
    if self.run_data.channel ~= self.mock_data.channel then
      self:fail("Channel mismatch in rich response")
    end
  end
end

-- Verify the plugin response contains a text element
function _M:responds_text()
  if not self.run_data then
    self:fail("Missing run data")
  else
    if not self.run_data.text then
      self:fail("No text in response")
    end
  end
end

-- Verify the plugin parses a message correctly
function _M:parses_text(regex, named_captures)
  local captures
  if not self.run_data then
    self:fail("Missing run data")
  else
    if type(named_captures) == 'string' then
      captures = {named_captures}
    elseif type(named_captures) == 'table' then
      captures = named_captures
    else
      self:fail("Named captures was not provided as a table or string")
    end
    local m, err = ngx.re.match(self.mock_data.text, regex, 'jo')
    if not m then
      self:fail("Got no matches for "..regex)
    else
      for _, c in ipairs(captures) do
        if not m[c] then
          self:fail("Did not get named capture "..c)
        end
      end
    end
  end
end

-- Verify a specific value was captured
function _M:captures_value(str, regex, capture)
  if not self.run_data then
    self:fail("Missing run data")
  else
    local m, err = ngx.re.match(self.mock_data.text, regex, 'jo')
    if not m then
      self:fail("Did not get any matches")
    else
      if not m[capture] then
        self:fail("Capture element "..capture.." was not found")
      else
        if m[capture] ~= str then
          self:fail("Expected "..str.." but got "..m[capture])
        end
      end
    end
  end
end

-- Verify the plugin reponse contains specific text
function _M:response_contains(...)
  local expects = self.expects or ...
  if not self.run_data then
    self:fail("Missing run data")
  elseif not expects then
    self:fail("Missing expectation")
  else
    local m, err = ngx.re.match(self.run_data.text, expects, 'jo')
    if not m then
      self:fail("Expected "..expects.." but got no matches")
    end
  end
end

function _M:reset()
  self.failures = {}
  self.tests = {}
end

function _M:fail(msg)
  table.insert(self.failures, msg)
end

function _M:add(func, ...)
  if ... then
    t = {
      name = func,
      args = {...}
    }
    table.insert(self.tests, t)
  else
    table.insert(self.tests, func)
  end
end

function _M:run()
  if not self.tests then
    self:pass("No tests to run")
  else
    for _, t in ipairs(self.tests) do
      local test_ok, test_res, test_name
      if type(t) == 'string' then
        test_name = t
        test_ok, test_res = pcall(_M[t], self)
      else
        test_name = t.name
        test_ok, test_res = pcall(_M[t.name], self, unpack(t.args))
      end
      if not test_ok then
        self:fail(test_name.." failed to run: "..test_res)
      end
    end
  end
end

function _M:report()
  local report = {}
  local failed = #self.failures
  if failed > 0 then
    report.tests = {}
    report.passed = false
    report.failures = self.failures
    for _, t in ipairs(self.tests) do
      if type(t) == 'string' then table.insert(report.tests, t) end
      if type(t) == 'table' then table.insert(report.tests, t.name) end
    end
    report.msg = "Failed "..failed.."/"..#report.tests
  else
    report.passed = true
    report.tests = self.tests
    report.msg = "All tests passed"
    report.response = self.run_data.text
  end
  return report
end

return m
