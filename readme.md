> Pasecinic Nichita
>
> Real-Time Programming in `Elixir`



A **message broker** implementation from scratch in *`Elixir`* 

This mono-repo contains several mix projects for a message broker implementation and simulation. More information can be found in dedicated `readme.md` and `/docs` directory for each project

- [`rtp_sse`](./rtp_sse/readme.md) - scalable tweets SSE handler with multiple worker pools with `MongoDB` bulk operations
- [`message_broker`](./message_broker/readme.md) - message broker implementation with persistent messages (saved in `JSON` logs), events priority, subscriber acknowledgements
- [`change_stream`](./change_stream) - [*CDC*](https://www.striim.com/blog/change-data-capture-cdc-what-it-is-and-how-it-works/) project that acts as publisher for topics (database collections) from [`rtp_sse`](./rtp_sse/readme.md)
- [`subscriber`](./subscriber) - client subscriber for [`message_broker`](./message_broker/readme.md) that subscribes to `tweets` and `users` topics and automatically acknowledges the received events (for a `message_broker` stress test)



### **Getting Started**

**Prerequisites:** A running `MongoDB` [replica set](https://www.mongodb.com/docs/manual/tutorial/deploy-replica-set/) instance on `mongodb://localhost:27017/rtp_sse_db`

1. Pull Tweets SSE server

```bash
# pull the docker image
$ docker pull alexburlacu/rtp-server:faf18x
# start the docker container on port 4000
$ docker run -p 4000:4000 alexburlacu/rtp-server:faf18x
```

2. Clone & dependency install for each project

```bash
$ git clone https://github.com/nichitaa/rtp_sse 
$ # similarly for `change_stream`, `rtp_sse` and `subscriber`
$ cd message_broker # cd in each project root directory
$ mix deps.get # and install required dependices
```

3. Start a new `iex` session for each project in the next order:

   1. `message_broker`

   1. `change_stream`

   1. `rtp_sse`

   1. `subscriber`

```bash
$ # similarly for `change_stream`, `rtp_sse` and `subscriber`
$ cd message_broker
$ iex -S mix
```

4. You can inspect the processes with elixirs' powerful observer tool (for each projects separatelly)

```elixir
# Start the builtin observer tool
iex(1)> :observer.start()
```

After you've got all 4 apps up and running you can connect to message broker and subscribe to a topic:

```bash
$ telnet localhost 8000
$ sub tweets # subscribe to `tweets` topic
$ # other available topic to subscribe to: `logger_stats`, `users`, `tweets_stats`, `users_stats`
```

Once created a subscriber connection to the message broker you can similarly connect and send `publish` commands

```bash
$ telnet localhost 8000
$ pub tweets {"id":"1", "priority": 3, "msg":"tweets topic test message"}
$ pub users {"id":"2", "priority": 4, "msg":"users topic test message"}
```

To start subscribers that will automatically `ack` each received events:

1. Start receiving tweets with`rtp_sse` project 

```bash
$ telnet localhost 8080 # connect to `rtp_sse` server
$ twitter # send `twitter` command to start receiving tweets from pulled docker container
```



To run it with `docker-compose up` change `localhost` s from each project `config.exs` file to related docker service from [`docker-compose.yml`](./docker-compose.yml). For example in [`change_stream/config/config.exs`](./change_stream/config/config.exs) replace:

```elixir
mongo_srv: "mongodb://localhost:27017/rtp_sse_db?replicaSet=rs0",
mb_host: 'localhost'
```

with:

```elixir
mongo_srv: "mongodb://mongodb_service:27017/rtp_sse_db?replicaSet=rs0",
mb_host: 'message_broker'
```

Obviously, there is much more to the project itself, but I'm sure you can

![figure-it-out](./message_broker/docs/images/figure-it-out.gif)
