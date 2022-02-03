#!/bin/bash
set -x

if [ -f  /sys/class/net/eth0/address ] ; then
  WAZIGATE_ID=$(cat /sys/class/net/eth0/address)
else
  if [ -f  /sys/class/net/wlan0/address ] ; then
    WAZIGATE_ID=$(cat /sys/class/net/wlan0/address)
  fi;
fi;
WAZIGATE_ID=${WAZIGATE_ID//:}

SSID="WAZIGATE_${WAZIGATE_ID^^}"

docker rm -f waziup.wazigate-mongo
docker image rm waziup/wazigate-mongo:4.4.11
docker run -d --restart=always --network=wazigate --name waziup.wazigate-mongo \
  -v "$PWD/wazigate-mongo/data:/data/db" \
  --health-cmd="echo 'db.stats().ok' | mongo localhost:27017/local --quiet" \
  --health-interval=10s \
  --entrypoint="mongod" \
  waziup/wazigate-mongo:4.4.11 --bind_ip_all

docker rm -f waziup.wazigate-edge
docker image rm waziup/wazigate-edge:64_v2
docker run -d --restart=always --network=wazigate --name waziup.wazigate-edge \
  -e "WAZIGATE_ID=$WAZIGATE_ID" \
  -e "WAZIGATE_VERSION=$WAZIGATE_VERSION" \
  -e "WAZIGATE_TAG=64_v2" \
  -e "WAZIUP_MONGO=unix:///tmp/mongodb-27017.sock" \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -v "/tmp/mongodb-27017.sock:/tmp/mongodb-27017.sock" \
  -v "/var/run/wazigate-host.sock:/var/run/wazigate-host.sock" \
  -v "$PWD/apps:/root/apps" \
  -p "80:80" -p "1883:1883" \
  waziup/wazigate-edge:64_v2

docker rm -f waziup.wazigate-system
docker image rm waziup/wazigate-system:$WAZIGATE_TAG
docker run -d --restart=unless-stopped --network=host --name waziup.wazigate-system \
  -v "/var/lib/wazigate/apps/waziup.wazigate-system:/var/lib/waziapp" \
  -v "/var/run:/var/run" \
  -v "/sys/class/gpio:/sys/class/gpio" \
  -v "/dev/mem:/dev/mem" \
  --privileged \
  --health-cmd="curl --fail --unix-socket /var/lib/waziapp/proxy.sock http://localhost/ || exit 1" \
  --health-interval=10s \
  waziup/wazigate-system:$WAZIGATE_TAG

docker rm -f waziup.wazigate-lora
docker image rm waziup/wazigate-lora:$WAZIGATE_TAG
docker run -d --restart=unless-stopped --network=wazigate --name waziup.wazigate-lora \
  -v "/var/lib/wazigate/apps/waziup.wazigate-lora:/var/lib/waziapp" \
  --health-cmd="curl --fail --unix-socket /var/lib/waziapp/proxy.sock http://localhost/ || exit 1" \
  --health-interval=10s \
  --label "io.waziup.waziapp=waziup.wazigate-lora" \
  waziup/wazigate-lora:$WAZIGATE_TAG


docker rm -f waziup.wazigate-lora.forwarders
docker image rm waziup/wazigate-lora-forwarders:latest
docker run -d --restart=unless-stopped --network=wazigate --name "waziup.wazigate-lora.forwarders" \
  -v "$PWD/apps/waziup.wazigate-lora/forwarders/:/root/conf" \
  -v "/var/run/dbus:/var/run/dbus" \
  -v "/sys/class/gpio:/sys/class/gpio" \
  -v "/dev:/dev" \
  -e "ENABLE_MULTI_SPI=1" \
  -e "ENABLE_MULTI_USB=1" \
  -e "ENABLE_SINGLE_SPI=1" \
  --device "/dev/ttyACM0:/dev/ttyACM0" \
  --privileged \
  --tty \
  --label "io.waziup.waziapp=waziup.wazigate-lora" \
  waziup/wazigate-lora-forwarders:latest


docker rm -f redis
docker image rm redis:6-alpine
docker run -d --restart=unless-stopped --network=wazigate --name redis \
  -v "redisdata:/data" \
  redis:6-alpine --appendonly yes --maxmemory 100mb --tcp-backlog 128


docker rm -f postgresql 
docker image rm postgres:alpine3.15
docker run -d --restart=unless-stopped --network=wazigate --name postgresql \
  -v "$PWD/apps/waziup.wazigate-lora/postgresql/initdb:/docker-entrypoint-initdb.d" \
  -v "postgresqldata:/var/lib/postgresql/data" \
  -e "POSTGRES_HOST_AUTH_METHOD=trust" \
  postgres:alpine3.15

docker rm -f waziup.wazigate-lora.chirpstack-gateway-bridge
docker image rm chirpstack/chirpstack-gateway-bridge:3.13.2
docker run -d --restart=unless-stopped --network=wazigate --name waziup.wazigate-lora.chirpstack-gateway-bridge \
  -v "$PWD/apps/waziup.wazigate-lora/chirpstack-gateway-bridge:/etc/chirpstack-gateway-bridge" \
  -p "1700:1700/udp" \
  --label "io.waziup.waziapp=waziup.wazigate-lora" \
  chirpstack/chirpstack-gateway-bridge:3.13.2

docker rm -f waziup.wazigate-lora.chirpstack-application-server
docker image rm chirpstack/chirpstack-application-server:3.17.4
docker run -d --restart=unless-stopped --network=wazigate --name waziup.wazigate-lora.chirpstack-application-server \
  -v "$PWD/apps/waziup.wazigate-lora/chirpstack-application-server:/etc/chirpstack-application-server" \
  -p "8080:8080" \
  --label "io.waziup.waziapp=waziup.wazigate-lora" \
  chirpstack/chirpstack-application-server:3.17.4


docker rm -f waziup.wazigate-lora.chirpstack-network-server
docker image rm chirpstack/chirpstack-network-server:3.15.5
docker run -d --restart=unless-stopped --network=wazigate --name waziup.wazigate-lora.chirpstack-network-server \
  -v "$PWD/apps/waziup.wazigate-lora/chirpstack-network-server:/etc/chirpstack-network-server" \
  --label "io.waziup.waziapp=waziup.wazigate-lora" \
  chirpstack/chirpstack-network-server:3.15.5


