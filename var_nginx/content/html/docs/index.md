# Lubot Documentation
Lubot is an experimental [Slack](https://slack.com) [chatbot](https://www.youtube.com/watch?v=NST3u-GjjFw) written in Lua hosted inside [OpenResty](http://openresty.org)

## Usage
To use lubot, you'll need four things:

- A slack bot integration
- A slack incoming webhook API key
- Docker
- This repo cloned locally

## Building
The repository ships with a `Makefile` you can use to run everything inside Docker.
From the root of the repository run the following:

```
make image
```

This will build a Docker image named `lubot` for you.

or to use a different name for the image:

```
docker build --rm -t <image name>
```

You should never blindly trust a random `Dockerfile` so look closely at the one shipped with the repo. Feel free to make changes but do so AFTER the core stuff is built.

## Running
If you used the `Makefile` to build, then you can start it up with:

```
DOCKER_ENV='--env LUBOT_PLUGIN_CONFIG=/var/nginx/lubot_plugins/lubot/plugins/plugins.json \
--env SLACK_API_TOKEN=<slack bot integration token> \
--env SLACK_WEBHOOK_URL="<slack webhook url>"' \
make run
```
If you build the container with a different name, the run command in the `Makefile` can be used as a starting point.

At this point you should see your bot visible in slack. Three basic example plugins ship out of the box:

- `ping`: Works similar to hubot's ping
- `status`: Returns some basic stats about the bot and slack account being used
- `image me`: Basic version of the hubot image me plugin

There is also a [webui](/docs/webui) available with some basic functionality and also an [api](/docs/api) that you can hit with curl.

## Customizing
See [customization](/docs/customizing)

## Additional plugins
See [plugins](/docs/plugins)
