#!/bin/bash

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF1
use somedb
db.helloDoc.countDocuments()
EOF1

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF2
use somedb
db.helloDoc.countDocuments()
EOF2

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF3
use somedb
db.helloDoc.countDocuments()
EOF3