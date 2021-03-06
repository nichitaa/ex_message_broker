import Config

config :rtp_sse,
       port: 8080,
       streams_no: 2, # we have 2 streams `/1` and `/2`
       wp_default_worker_no: 5, # start worker pools with default 5 workers
       wp_start_delay: 100, # start workers after 100 ms
       wp_terminate_delay: 4000, # for safe worker termination (each 4 seconds check for empty worker message queue then terminate it)

       ss_delay: 100, # stream supervisor delay (start all tree structure after 200ms)
       sse_base_url: "http://localhost:4000/tweets", # use sse_api when running inside docker container

       sse_start_delay: 2000, # start receiving SSEs after 2 sec

       logger_min_sleep: 50,
       logger_max_sleep: 500,

       max_batch_size: 200, # limit for batch size (tweets[] and users[])
       batcher_flush_time: 3000, # 3 seconds flush time for batcher

       ue_user_batch_size: 100, # limit for user engagements
       ue_flush_time: 3000, # flush time for user engagements

       # for debug better disable autoscaler and ignore panic messages
       enable_autoscaler: true,
       ignore_panic_message: false,

       autoscaler_time_frame: 1000,

       mongo_srv: "mongodb://localhost:27017/rtp_sse_db", # use mongodb_service when running inside docker container
       db_bulk_size: 50, # Mongo max bulk size for 200 documents bulk upload
       db_tweets_collection: "tweets", # collection names
       db_users_collection: "users",
       db_users_engagements_collection: "users_engagements",

       hashtags_flush_time: 3000, # save hashtags to JSON every 3 sec

       mb_host: 'localhost', # Message Broker host, in binary, as expected by :gen_tcp, use message_broker with docker
       mb_port: 8000,
       mb_publish_command: "pub", # PUBLISH
       # topic for this producer app
       mb_tweets_topic: "tweets",
       mb_user_topic: "users",
       # statistics topics
       mb_logger_stats_topic: "logger_stats",
       mb_users_stats_topic: "users_stats",
       mb_tweets_stats_topic: "tweets_stats"