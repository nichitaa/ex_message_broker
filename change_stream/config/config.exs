import Config

config :change_stream,
       mongo_srv: "mongodb://localhost:27017/rtp_sse_db?replicaSet=rs0",

       mb_host: 'localhost', # Message Broker host, in binary, as expected by :gen_tcp
       mb_port: 8000,
       mb_publish_command: "pub", # PUBLISH

       # collection names
       db_tweets_collection: "tweets",
       db_users_collection: "users",
       db_users_engagements_collection: "users_engagements"
