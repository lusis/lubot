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
- If the result has an attachment element, it attempts to send that over the incoming webhook. If you've not provided a webhook url the `fallback` text required by the slack api is used instead and sent over websockets. If you do not provide a fallback yourself, the fields of your attachment will be converted to build a fallback message.

### Plugin location
The plugins are located in the `var_nginx/lubot_plugins/` directory. There are three sub-directories:
- `core`: core plugins
- `contrib`: third-party plugins
- `user`: local plugins

The lua search path for lubot will look in the following order: user -> core -> contrib. This feels like the sanest mechanism for overrides.

They currently have the following restrictions:
- Must be named `lubot_<command name>.lua` and must return a table matching an RTM message object
- If returning an attachment, you must follow the slack formatting rules for attachments returned as a table of attachments

For examples see the three existing plugins. The `status` plugin sends an attachment.

One nice thing about these plugins is that you can test them with curl:

```
jvbuntu :: ~ » curl -XPOST -d'{"channel":"foo","user":"test","text":"lubot image me foobar","expects":"foobar"}' http://localhost:3232/api/plugins/test/image

{"expected":"foobar","results":"http:\/\/khromov.files.wordpress.com\/2011\/02\/foobar_cover.png","passed":true,"got":"foobar"}
```

Some plugins don't have any assertions you can provide. Take the ping plugin:

```
jvbuntu :: ~ » curl -XPOST -d'{"channel":"foo","user":"test"}' http://localhost:3232/api/plugins/test/ping  
{"expected":"^pong .*$","passed":true,"got":"pong (1420583382)"}
```

## API
You may have noticed in the plugin testing section, the call to `/api/plugins`. Pretty much everything inside lubot is an api call to itself. This provides the benefit of being able to use it with multiple tools. Lubot listens on two ports - `3232` and `3131`. Public communications are handled over `3232`. However internally, all api calls go to `3131`. You should never expose `3131` to the public. Instead you should `proxy_pass` requests to the private port. The api called for testing does just that (`var_nginx/conf.d/lubot.conf`):

```
  location /api {
    lua_code_cache off;
    proxy_pass_request_headers on;
    proxy_redirect off;
    proxy_buffering off;
    proxy_cache off;
    rewrite ^/api/(.*) /_private/api/$1 break;
    proxy_pass http://private_api;
  }
```

The corresponding private api config (in `var_nginx/conf.d/private.conf`):

```
  location /_private/api {
    lua_code_cache off;
    content_by_lua_file '/var/nginx/lua/api.lua';
  }
```

# Customization
More customization information is available from the web ui inside lubot. These are just markdown files served by lubot and they are available in `var_nginx/content/html/docs`

The general idea for customization is a combination of:

- nginx includes at critical points
- environment variables
- predefined site-specific directories on the lua load path before core load paths

In general you should not need to touch ANY shipped files unless you are developing core functionality.

# Production ready
Actually...yeah...kinda. I'll probably move the websocket connection back out of the `init_by_lua` and into the worker the way it works in the sysadvent container.
Also note that having a worker handling the websocket stuff means that worker cannot service nginx requests because it's being blocked.

# TODO
- Create a management API and page to be served
- Possibly migrate the websocket logic back into `init_worker_by_lua`
- Maybe consider porting this to hipchat or something

