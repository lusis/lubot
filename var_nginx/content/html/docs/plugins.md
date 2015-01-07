# Plugins
Plugins in lubot are pretty straight forward. The boilerplate required is very minimal. In general a lubot plugin has the following required structure:

```lua
local plugin = {}

plugin.id = "something"       -- The name of your plugin
plugin.version = "0.0.1"      -- A version string - arbitrary text
plugin.regex = [[something]]  -- The keyword that will route the message to this plugin

-- internal requirements/shipped helpers. You probably want these.
local plugins  = require 'utils.plugins'
local slack    = require 'utils.slack'

function plugin.run(data)
  local text = "Hello from lubot"
  return slack.say(text)
end

-- optional test support
function plugin.test(data)
  local res = plugin.run(data)
  local expects = [=[^Hello from .*$]=]
  local params = {
    mock_data = data,
    run_data = res
  }
  local t = require('utils.test').new(params)
  -- does it contain a text key (required for slack RTS responses)
  t:add("responds_text")
  -- does the response match a given regex or string
  t:add("response_contains", expects)
  -- run the test
  t:run()
  -- return the report
  return t:report()
end

return plugin
```

If you save the text above to `/var_nginx/lubot_plugins/user/lubot_something.lua`, the plugin is now available without restarting lubot.

## Running the plugin
You can use plugins with curl fairly easily:

```
» curl -s -XPOST -d'{"channel":"foo","user":"test"}' http://localhost:3232/api/plugins/run/something | python -mjson.tool
{
      "text": "Hello from lubot"
}
```

## Plugin tests
Lubot plugins have optional support for testing using a mini-test suite approach. It's a tad bit verbose but as tests actually run the plugin, it allows you to define precisely how far you want to test. Using the following tests for our sample plugin above:

```lua
function plugin.test(data)
  local res = plugin.run(data)
  local expects = [=[^Hello from .*$]=]
  local params = {
    mock_data = data,
    run_data = res
  }
  local t = require('utils.test').new(params)
  -- does it contain a text key (required for slack RTS responses)
  t:add("responds_text")
  -- does the response match a given regex or string
  t:add("response_contains", expects)
  -- run the test
  t:run()
  -- return the report
  return t:report()
end
```

You can test the plugin with curl like so:

```
» curl -s -XPOST -d'{"channel":"foo","user":"test", "text":"lubot something"}' http://localhost:3232/api/plugins/test/something | python -mjson.tool
{
    "msg": "All tests passed",
    "passed": true,
    "response": "Hello from lubot",
    "tests": [
        "responds_text",
        {
            "args": [
                "^Hello from .*$"
            ],
            "name": "response_contains"
        }
    ]
}
```

Tests with failures look like this:

```
» curl -s -XPOST -d'{"channel":"foo","user":"test","text":"lubot something"}' http://localhost:3232/api/plugins/test/something | python -mjson.tool
{
    "failures": [
        "Expected ^foobar but got no matches"
    ],
    "msg": "Failed 1/2",
    "passed": false,
    "tests": [
        "responds_text",
        "response_contains"
    ]
}
```

### Test Methods
The following methods are available for use in tests:

- `is_valid_rich_text()`: is the response valid for sending as a webhook with attachments
- `responds_text()`: does the response contain a text response
- `parses_text(regex, named_captures)`: does `regex` result contain the `named_captures`. `named_captures` can be either a string or a table containing multiple named captures
- `captures_value(str, regex, capture)`: does running `regex` against `str` result in `capture`. `capture` can either be an integer (for an index) or a named capture. Reminder lua indexes start at `1` not `0`
- `response_contains(str)`: does the response contain `str`. `str` is not required. If not provided, the value of `t.expects` will be used.


