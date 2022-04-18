import Config

config :message_broker,
       port: 8000,

       tweet_producer_host: 'localhost', # in binary, as expected by :gen_tcp
       tweet_producer_port: 8080,
       clean_log_file: true, # clean log file on application startup

       # commands
       publish_command: "pub", # PUBLISH
       subscribe_command: "sub", # SUBSCRIBE
       unsubscribe_command: "unsub", # UNSUBSCRIBE
       acknowledge_command: "ack", # ACKNOWLEDGE

       logs_dir: "logs", # logs directory

       # some topics for the lab2 (producer)
       tweets_topic: "tweets",
       users_topic: "users"
