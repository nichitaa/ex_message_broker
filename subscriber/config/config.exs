import Config

config :subscriber,
       port: 9000,

       # message broker
       mb_port: 8000,
       mb_host: 'localhost',
       mb_subscribe_command: "sub",
       mb_acknowledge_command: "ack",
       mb_topic: "tweets"