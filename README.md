# Lubot
Proof of concept Slack chatbot hosted entirely inside nginx

## Motivation
The main motivation for this was an extension of work I did for my [SysAdvent 2014 post](http://sysadvent.blogspot.com/2014/12/day-22-largely-unappreciated.html) on Nginx, Lua and OpenResty.
For that post I created a [docker container](https://github.com/lusis/sysadvent-2014) to run the examples/tutorials. Part of those tutorials were a couple of Slack RTM clients - one of which was nginx/openresty operating as a [websocket client](https://github.com/lusis/sysadvent-2014/blob/master/var_nginx/lua/slack.lua).

I got it in my head that I could write a [hubot clone](https://github.com/github/hubot) using that.

## How it works
This is a prefab container like the previous example. A `Makefile` is provided to set everything up. You'll need to create a [Slack Bot User](https://api.slack.com/bot-users) and optionally you'll need an incoming webhook url (if you want to use rich formatting) as the [RTM Api doesn't support those yet](https://twitter.com/slackapi/status/542912319957643265)

Build and start the container like so:
`DOCKER_ENV='--env SLACK_API_TOKEN=xoxb-XXXXXXX --env SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXXXXX"' make all`

(future invocations after the initial build can use `make run` in place of `make all`)

You can watch the logs via `tail -f var_nginx/logs/error.log`.

# How it works
During startup, one of the nginx worker threads will connect as a websocket client to the RTM api. During the authentication response from Slack, the user/group/etc data is loaded into a shared dict. This is largely unused right now.

The bot will be auto-joined to the `#general` channel. I'd suggest either opening a private message session with it or a dedicated private channel.

## Plugins
Hubot has plugins. Lubot has plugins but they're "different". The way lubot plugins work are:

- A message prefixed with the botname (default `lubot`) is noted.
- The first word after the botname is considered the command (this will change)
- The command is parsed and an http request is made to `http://127.0.0.1:3131/lubot_plugin?plugin=<command>` (this is a `content_by_lua_file` script - `var_nginx/lua/lubot_plugin.lua`)
- The plugin is executed in a fairly "safe" manner and the response is returned to be sent to slack via the existing websocket connection
- If the result has an attachment element, it attempts to send that over the incoming webhook. If you've not provided a webhook url the `fallback_text` required by the slack api is used instead and sent over websockets.

### Plugin location
The plugins are located in the `var_nginx/lubot_plugins/lubot/plugins` directory. They currently have the following restrictions:
- Must be named `lubot_<command name>.lua` and must return a table matching an RTM message object
- If returning an attachment, you must follow the slack formatting rules for attachments returned as a table

For examples see the three existing plugins. The `status` plugin sends an attachment.

One nice thing about these plugins is that you can test them with curl:

```
jvbuntu :: ~ » curl -s -d'{"channel":"foo","user":"test","text":"lubot image me snafu"}' "http://localhost:3232/lubot_plugin?plugin=image"
{"type":"message","channel":"foo","text":"http:\/\/img3.wikia.nocookie.net\/__cb20100606064554\/thepacific\/images\/7\/7e\/Snafu-Helmet.jpg","id":"101419451743"}
```

The format for the plugins is far from settled. There's a lot of repetition and some sugar needed to make them easier to write.

# Production ready
Not bloody likely. I'll probably move the websocket connection back out of the `init_by_lua` and into the worker the way it works in the sysadvent container.
Also note that having a worker handling the websocket stuff means that worker cannot service nginx requests because it's being blocked.

# TODO
- Create a management API and page to be served
- Possibly migrate the websocket logic back into `init_worker_by_lua`

