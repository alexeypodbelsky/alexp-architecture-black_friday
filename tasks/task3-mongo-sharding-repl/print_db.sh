#!/bin/bash

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb

print("--- Sharding Status ---");
sh.status();
print("\n");

print("--- Shard Distribution for somedb.helloDoc ---");
db.helloDoc.getShardDistribution();
print("\n");

print("--- Total Documents in somedb.helloDoc ---");
let documentCount = db.helloDoc.count();
print("Total documents: " + documentCount);
EOF

echo "Sharding status and document count retrieved."

