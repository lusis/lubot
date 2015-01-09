# Plugins
Plugins in lubot are pretty straight forward. The boilerplate required is very minimal. In general a lubot plugin has the following required structure:

```lua
local plugin = {}

plugin.id = "something"       -- The name of your plugin. Will be concatenated with `lubot_` to locate the module
plugin.version = "0.0.1"      -- A version string - arbitrary text
plugin.regex = [[something]]  -- The keyword that will route the message to this plugin. Never use a start-of-string token here 

-- internal requirements/shipped helpers. You probably want these.
local plugins  = require 'utils.plugins'
local slack    = require 'utils.slack'

function plugin.run(data)
  local text = "Hello from lubot"
  return slack.say(text)
end

function plugin.help()
  local h = [[This plugin says things]]
  return h
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

## Breakdown
Plugin routing uses the following flow (using the above plugin as an example)

- match msg text (without the botname prefix) against the regex for each active plugin (this needs instrumenting)
- makes an internal http api request (over unix domain socket) to `/_private/api/plugins/run/<plugin.id>` passing in the message data

Once the api request takes over, the following happens:

- concatenate the id of plugin with `lubot_` (i.e `lubot_something` using the above example)
- safely load the plugin
- call the `run` function on the plugin with the message data as the argument

The api passes the json response back up to the websocket session. If the message was a rich text message, it's sent via webhook otherwise response is over websockets

It seems complicated but the benefit here is that by internally using an HTTP api, the same flow can be used for testing entirely outside of the chat session. No need for a console plugin of any kind.

In general, all you need to know is that plugins must define the following:

- `id`: used to concatenate and load the module as `lubot_<id>`
- `regex`: used to match the text addressed to the botname (excluding the botname)
- `version`: unused for now but still required
- a run function

## Activating the plugin
Save the above plugin as `var_nginx/lubot_plugins/user/lubot_something.lua`.
Activate the plugin either via API (`/api/plugins/activate/<plugin_id>`) or chat (`lubot plugins activate <plugin_id>`)

## Running the plugin
You can use plugins with curl fairly easily:

```
» curl -s -XPOST -d'{"channel":"foo","user":"test"}' http://localhost:3232/api/plugins/run/something | python -mjson.tool
{
      "text": "Hello from lubot"
}
```


## Plugin tests
Lubot plugins have optional support for testing using a mini-test suite approach. It's a tad bit verbose but as this test actually runs the plugin, it allows you to define precisely how far you want to test. Using the following tests for our sample plugin above:

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


