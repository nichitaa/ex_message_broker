import Config

config :message_broker,
       port: 8000,

       tweet_producer_host: 'localhost', # in binary, as expected by :gen_tcp
       tweet_producer_port: 8080,

       # commands
       publish_command: "pub", # PUBLISH
       subscribe_command: "sub", # SUBSCRIBE
       unsubscribe_command: "unsub", # UNSUBSCRIBE
       acknowledge_command: "ack" # ACKNOWLEDGE
