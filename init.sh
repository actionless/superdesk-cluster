#!/bin/sh
set -ue

# wait for mongo to listen on its port:
TIMEOUT=2
TARGETS=(
	localhost
	mongors1srv1.mongo.docker
	mongors1srv2.mongo.docker
	mongors1srv3.mongo.docker
	mongors2srv1.mongo.docker
	mongors2srv2.mongo.docker
	mongors2srv3.mongo.docker
	mongocfg1.mongo.docker
	mongocfg2.mongo.docker
	mongocfg3.mongo.docker
)
for TARGET in ${TARGETS[@]}
do
	echo "waiting for $TARGET:"
	MONGO=0
	while [ $MONGO -eq 0 ]
	do
		docker exec -ti cluster_mongos_1 curl -s -m $TIMEOUT $TARGET:27017 2>&1 > /dev/null \
		&& MONGO=1 \
		|| { echo -n "." ; sleep $TIMEOUT ;}
	done
	echo
done

# init replica set 1:
docker exec -ti cluster_mongors1srv1_1 mongo --eval 'rs.initiate(); rs.add("mongors1srv2.mongo.docker:27017"); rs.add("mongors1srv3.mongo.docker:27017"); rs.status()'
docker exec -ti cluster_mongors1srv1_1 mongo --eval 'cfg = rs.conf(); cfg.members[0].host = "mongors1srv1.mongo.docker:27017"; rs.reconfig(cfg); rs.status()'
# init replica set 2:
docker exec -ti cluster_mongors2srv1_1 mongo --eval 'rs.initiate(); rs.add("mongors2srv2.mongo.docker:27017"); rs.add("mongors2srv3.mongo.docker:27017"); rs.status()'
docker exec -ti cluster_mongors2srv1_1 mongo --eval 'cfg = rs.conf(); cfg.members[0].host = "mongors2srv1.mongo.docker:27017"; rs.reconfig(cfg); rs.status()'
# add shard
docker exec -ti cluster_mongos_1 mongo --eval 'sh.addShard("rs1/mongors1srv1.mongo.docker:27017"); sh.addShard("rs2/mongors2srv1.mongo.docker:27017"); sh.status()'
