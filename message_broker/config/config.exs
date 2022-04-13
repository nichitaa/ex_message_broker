import Config

config :message_broker,
       port: 8000,

       tweet_producer_host: 'localhost', # in binary, as expected by :gen_tcp
       tweet_producer_port: 8080,

       delimiter: "|>>>", # delimiter between mb command and data
       publish_command: "PUBLISH",
       subscribe_command: "SUBSCRIBE",
       unsubscribe_command: "UNSUBSCRIBE"
