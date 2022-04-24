import Config

config :message_broker,
       port: 8000,

       # worker pool configs
       wp_terminate_delay: 3000, # for 'soft' worker kill
       wp_start_delay: 100,
       wp_default_worker_no: 10,
       autoscaler_time_frame: 1000, # 1 sec
       wp_autoscale_proportion: 2,
       enable_autoscaler: true,

       # for persistent messages (save published events to logs)
       batcher_flush_time: 2000, # 2 sec

       tweet_producer_host: 'localhost', # in binary, as expected by :gen_tcp
       tweet_producer_port: 8080,

       # commands
       publish_command: "pub", # PUBLISH
       subscribe_command: "sub", # SUBSCRIBE
       unsubscribe_command: "unsub", # UNSUBSCRIBE
       acknowledge_command: "ack", # ACKNOWLEDGE

       # logs config
       logs_dir: "logs", # directory
       clean_logs_on_startup: true, # does what it says, in dev mode I don't need them

       # some topics for the lab2 (producer)
       tweets_topic: "tweets",
       users_topic: "users",

       # utils
       debug_io_time: true
