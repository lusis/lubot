# Nginx and Websocket Workflow
The following convoluted diagram traces the flow from nginx startup to message proccessing.

![engine-workflow](/img/bot-engine-workflow.png)

As stated previously, one worker is selected through a locking mechanism to actually connect to the Slack websocket. Since this a blocking behaviour, that worker is essentially removed from the pool for handling http requests. This isn't a big deal if lubot is only dealing with being a bot and responding to messages. It's a bigger deal if lubot is embedded in an existing nginx installation that normally services http requests.
