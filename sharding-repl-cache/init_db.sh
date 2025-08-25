#!/bin/bash

# Функция для проверки статуса репликасета
function wait_for_replset {
  local replset_name="$1"
  local container="$2"
  local port="$3"
  local timeout=60 # seconds
  local start_time=$(date +%s)

  echo "Waiting for replset $replset_name to be ready..."
  while true; do
    local status=$(docker compose exec -T "$container" mongosh --port "$port" --quiet --eval "try { rs.status().ok } catch (e) { 0 }")
    if [[ "$status" -eq 1 ]]; then
      echo "Replset $replset_name is ready."
      return 0
    fi

    local elapsed=$(( $(date +%s) - start_time ))
    if [[ "$elapsed" -gt "$timeout" ]]; then
      echo "Timeout waiting for replset $replset_name."
      return 1
    fi

    sleep 2
  done
}


# Инициализация config server
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

# Ждем готовности config server
wait_for_replset "config_server" "configSrv" 27017 || exit 1

# Инициализация shard1
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

# Ждем готовности shard1
wait_for_replset "shard1" "shard1-1" 27018 || exit 1

# Инициализация shard2
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

# Ждем готовности shard2
wait_for_replset "shard2" "shard2-1" 27019 || exit 1

# Настройка mongos router
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF4
sh.addShard( "shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018");
sh.addShard( "shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019");
use somedb
sh.enableSharding("somedb");
db.helloDoc.createIndex( { name: "hashed" } )
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
EOF4

echo "Sharding setup complete."