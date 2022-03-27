import Config

config :rtp_sse,
       port: 8080,
       wp_default_worker_no: 5, # start worker pools with default 5 workers
       wp_start_delay: 100, # start workers after 100 ms
       wp_terminate_delay: 4000, # for safe worker termination (each 4 seconds check for empty worker message queue then terminate it)

       ms_delay: 100, # main supervisor delay (start all tree structure after 200ms)
       sse_base_url: "http://localhost:4000/tweets",

       sse_start_delay: 2000, # start receiving SSEs after 2 sec

       logger_min_sleep: 50,
       logger_max_sleep: 500,

       max_batch_size: 200, # limit for batch size (tweets[] and users[])
       batcher_flush_time: 3000, # 3 seconds flush time for batcher

       # for debug better disable autoscaler and ignore panic messages
       enable_autoscaler: false,
       ignore_panic_message: true,

       autoscaler_time_frame: 1000,

       mongo_srv: "mongodb://localhost:27017/rtp_sse_db",
       db_bulk_size: 50, # Mongo max bulk size for 200 documents bulk upload
       db_tweets_collection: "tweets", # collection names
       db_users_collection: "users",

       hashtags_flush_time: 3000 # save hashtags to JSON every 3 sec
