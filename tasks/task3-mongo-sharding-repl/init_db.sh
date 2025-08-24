#!/bin/bash

sleep 2

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF1
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
)
EOF1

sleep 2

docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF2
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1-1:27018" },
        { _id : 1, host : "shard1-2:27018" },
        { _id : 2, host : "shard1-3:27018" }
      ]
    }
)
EOF2

sleep 2

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF3
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2-1:27019" },
        { _id : 1, host : "shard2-2:27019" },
        { _id : 2, host : "shard2-3:27019" }
      ]
    }
  )
EOF3

sleep 3

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF4
sh.addShard( "shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
sh.addShard( "shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");
use somedb
sh.enableSharding("somedb");
db.helloDoc.createIndex( { name: "hashed" } )
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
EOF4