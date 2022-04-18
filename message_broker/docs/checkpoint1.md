> Pasecinic Nichita
>
> Real-Time Programming in `Elixir`



`MessageBroker` is TCP server running on port `8000` created with [erlang `:gen_tcp` module](https://www.erlang.org/doc/man/gen_tcp.html), any client / producer can connect to it via a tool like `telnet` or `netcat`.

```bash
$ telnet localhost 8000 # if running the app locally 
```

The list of commands is defined in [config.ex](../config/config.exs) (using a shorthand command for dev mode, but those
can be easily changed):

* `pub` (`PUBLISH`) - publish a message to a topic, if topic does not exist it will create it,
  usage: `pub topic JSON_escaped_data` (e.g.: `pub tweets {"id":"1", "priority": 3, "msg":"tweet 1"}`)
* `sub` (`SUBSCRIBE`) - subscribes a client to a topic, respond with error message if topic does not exist,
  usage: `sub topic` (e.g.: `sub tweets`)
* `unsub` (`UNSUBSCRIBE`) - unsubscribes a subscriber from a topic, usage: `unsub topic` (e.g.: `unsub tweets`)
* `ack` (`ACKNOWLEDGE`)- notifies the `MessageBroker` about a successful delivered message from subscriber,
  usage: `ack topic event_id` (e.g.: `ack tweets 1`)

Each received event for a `pub` command is expected to be of an [`EventDto`](../lib/message_broker/dtos/event.ex) format.  For each topic is created a log file with the topic name (e.g.: `tweets.json`), the `logs` directory is git-ignored. An example of how this a topic log file is structure is the [`logs.public.json`](../logs.public.json) file:

```json
// tweets.json
{
  "subscriber": [
    {
      "timestamp": 1650054011933,
      "priority": 5,
      "msg": "msg",
      "id": "1"
    },
    {
      "timestamp": 1650054144283,
      "priority": 4,
      "msg": "msg",
      "id": "2"
    }
  ]
}
// real tweets.json
{
  "#Port<0.6>": [
    {
      "timestamp": 1650308403348,
      "priority": 6,
      "msg": "tweet text",
      "id": "042"
    },
    {
      "timestamp": 1650308398178,
      "priority": 6,
      "msg": "tweet text",
      "id": "04c"
    }
  ]
}

```

 The key is the subscriber/client, it can be used any client identifiers, now using the [`Elixir` Port](https://hexdocs.pm/elixir/1.13/Port.html) for the subscriber connection (e.g.: `#Port<0.5>`), and the values is list (our Priority queue) of events that did not received yet an acknowledgment from subscriber (`ack` command).

### **`MessageBroker` message exchange diagram**

![mb_message_exchange](./images/mb_message_exchange.png)